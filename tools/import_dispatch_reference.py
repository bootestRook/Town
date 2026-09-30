"""Import FightSetPnl sprites and the first difficulty's four map definitions."""
import csv
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG

ART = {
    'frame':'diban_da', 'town':'yx_sz_dikuang1', 'field':'yx_sz_dikuang2',
    'field2':'yx_sz_dikuang3', 'field3':'yx_sz_dikuang4', 'tab':'yx_sz_yeqian1',
    'selected':'yx_sz_xuanzhong', 'town_title':'yx_sz_dikuang_biaoti1',
    'power':'yx_sz_dikuang_biaoti2', 'title':'yx_sz_dikuang_biaoti3',
    'fade':'yx_sz_dikuang_zhezhao', 'move':'diban_anniu2', 'warning':'common_hongdian1',
}


def main():
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    bindings, provenance = [], {}
    for name, frame in ART.items():
        row = next(r for r in frames if r['bundle']=='resources' and r['frame_name']==frame)
        source = SOURCE/row['output']
        provenance[name] = dict(source=row['output'], uuid=row['uuid'], sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        for base in ['art_source','assets/runtime']:
            target = ROOT/base/'dispatch'/f'{name}.png'
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            write_json(target.with_suffix('.png.json'), dict(prompt=f"Source sprite {row['uuid']} ({frame}), from the user-provided Mercenary Town extraction: {row['output']}. Copied unchanged; no generated pixels.", source_sha256=provenance[name]['sha256']))
        bindings.append(dict(id='dispatch.'+name, asset_kind='texture_2d', source_path=f'art_source/dispatch/{name}.png', runtime_path=f'res://assets/runtime/dispatch/{name}.png', policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
    write_json(ROOT/'art_source/dispatch/provenance.json', provenance)
    path = ROOT/'data/source/resource_bindings.csv'
    rows = list(csv.DictReader(path.open(encoding='utf-8')))
    write_csv(path, [r for r in rows if not r['id'].startswith('dispatch.')]+bindings)
    source_map = read_json(CFG/'c8_map.json')[0]
    rows = []
    for i, (area, name) in enumerate([('town','主城'),('field','兽人密林'),('field2','亡灵墓地'),('field3','魔族战场')]):
        rows.append(dict(id=area, display_name=name, power=source_map[f'yq{i}'] if i else 0,
                         dungeon=source_map[f'yq{i}_dungeon'] if i else 0, combat_enabled='true' if i else 'false'))
    write_csv(ROOT/'data/source/town/town_dispatch.csv', rows)
    path = ROOT/'data/schema/data_schema.json'
    schema = read_json(path)
    schema['tables']['town_dispatch'] = dict(source='town/town_dispatch.csv', **{'class':'definition'}, primary_key=['id'], fields=[
        dict(name='id', type='ref', table='town_regions', field='id', required=True),
        dict(name='display_name', type='string', required=True),
        dict(name='power', type='int', min=0, required=True),
        dict(name='dungeon', type='int', min=0, required=True),
        dict(name='combat_enabled', type='bool', required=True)])
    write_json(path, schema)
    print('Dispatch:', len(bindings), 'source sprites, four first-difficulty areas')


if __name__ == '__main__': main()
