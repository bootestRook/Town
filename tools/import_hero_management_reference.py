"""Import HeroStandby artwork and catalog/camp definitions from the local source dump."""
import csv
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG


def main():
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup = {key: row for row in frames for key in (row['uuid'], row['frame_name'], row['name'])}
    art = {'camp': 'liebiao_bj', 'count': 'liebiao_renshu_diban', 'pedestal': 'liebiao_taizi1',
           'add': 'liebiao_taizi2', 'lock': 'common_weijiesuo', 'check': 'common_wancheng',
           'filter': 'sq_liebiao_all', 'filter_selected': 'liebiao_shaxuan_xuanzhong',
           'category': 'liebiao_yeqian2', 'category_selected': 'liebiao_yeqian1',
           'training_row': 'yx_shengxingtiao', 'upgrade': 'liebiao_anniu',
           'deployed': 'd042ecd6-ce17-4e0f-a5aa-4817ff6acf84',
           'tab_1': 'yx_yeqian5', 'tab_1_selected': 'yx_yeqian5_xuanzhong',
           'tab_2': 'yx_yeqian6', 'tab_2_selected': 'yx_yeqian6_xuanzhong'}
    records, bindings = {}, []
    for name, key in art.items():
        row = lookup[key]
        original = SOURCE/row['output']
        record = {'source': row['output'], 'uuid': row['uuid'], 'sha256': hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/hero_management', 'assets/runtime/hero_management']:
            target = ROOT/directory/(name+'.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, target)
            write_json(target.with_suffix('.png.json'), {'prompt': 'Original Mercenary Town sprite; not AI generated.', 'source': record})
        records[name] = record
        bindings.append(dict(id='hero_management.'+name, asset_kind='texture_2d', source_path='art_source/hero_management/'+name+'.png', runtime_path='res://assets/runtime/hero_management/'+name+'.png', policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
    write_json(ROOT/'art_source/hero_management/provenance.json', records)
    previous = [r for r in csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8')) if not r['id'].startswith('hero_management.')]
    write_csv(ROOT/'data/source/resource_bindings.csv', previous+bindings)
    schema = read_json(ROOT/'data/schema/data_schema.json')
    heroes = list(csv.DictReader((ROOT/'data/source/town/main_heroes.csv').open(encoding='utf-8')))
    talents = {r['id']:r for r in read_json(CFG/'c29_tf2.json')}
    catalog = []
    for row in read_json(CFG/'tujian.json'):
        matches = [h for h in heroes if int(h['source_id'])//100 == row['original_id']//100]
        if not matches: continue
        show = talents[row['show_id']]
        catalog.append(dict(id=matches[0]['id'], show_talent=row['show_id'], star=show['star'], rank=row['rank']))
    # Some source rows share a series; one library card per available definition.
    catalog = list({r['id']:r for r in catalog}.values())
    write_csv(ROOT/'data/source/town/main_hero_catalog.csv', catalog)
    for name, fields in [('main_hero_catalog',[('id','id'),('show_talent','int'),('star','int'),('rank','int')])]:
        schema['tables'][name] = {'source':'town/'+name+'.csv','class':'definition','primary_key':['id'],'fields':[{'name':key,'type':kind,'required':True} for key,kind in fields]}
    write_json(ROOT/'data/schema/data_schema.json', schema)
    from import_hero_camp_reference import import_levels
    print('Hero management:', len(art), 'sprites,', len(catalog), 'catalog records,', import_levels(), 'camp levels')


if __name__ == '__main__': main()
