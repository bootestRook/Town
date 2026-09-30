"""Import the source hero camp panel, names and coin-only level definitions."""
import csv
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG

ART = {
    'backdrop': '920cecdc-41d1-4386-bc56-c460a5c93dc5',
    'banner': '1deea7d3-ab12-42b8-bea0-be4bdf6ddc79',
    'upgrade_panel': '548adf23-b9d6-4dd2-9b16-dd646c11df2c',
    'chain': '86a51799-9146-40ca-9c1e-ced5e57d9de9',
    'section': '0c45da94-75f7-4644-a134-9acc32b1c9fe',
    'capacity': 'bbef83c7-83f3-4895-ab83-c716acc9b6a2',
    'preview': '5cd7d41c-6f45-43b3-8f68-3049259ce9df',
    'body': '1a313651-536e-4e29-a55b-9489c0eb7149',
    'bottom': '9caedb34-1022-48e8-a223-199315d2f05b',
    'people': 'd31dc1d8-a074-4edc-8fbc-41ec0a46f32a',
    'divider': 'f0b166d3-5676-40f8-aa17-7ede9bb3663a',
    'coin_bar': '68342bf0-3722-424d-a25e-9bf514730612',
}


def import_levels():
    rows = [dict(id='camp.'+str(r['id']), level=r['id'], capacity=r['num'],
                 cost=int(r['xh'].split(':')[1]) if r['xh'] != '-1' else 0)
            for r in read_json(CFG/'c58_gongyu.json')]
    write_csv(ROOT/'data/source/town/main_hero_camp.csv', rows)
    schema = read_json(ROOT/'data/schema/data_schema.json')
    schema['tables']['main_hero_camp'] = {
        'source': 'town/main_hero_camp.csv', 'class': 'definition', 'primary_key': ['id'],
        'fields': [dict(name='id', type='id', required=True)] + [
            dict(name=k, type='int', required=True, min=minimum, **({'max': maximum} if maximum else {}))
            for k, minimum, maximum in [('level',1,13), ('capacity',3,15), ('cost',0,None)]]}
    write_json(ROOT/'data/schema/data_schema.json', schema)
    return len(rows)


def main():
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup = {r['uuid']: r for r in frames if r['bundle'] == 'resources'}
    records, bindings = {}, []
    for name, uuid in ART.items():
        row = lookup[uuid]
        source = SOURCE/row['output']
        records[name] = dict(source=row['output'], uuid=uuid, sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        for base in ['art_source','assets/runtime']:
            target = ROOT/base/'hero_camp'/f'{name}.png'
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        bindings.append(dict(id='hero_camp.'+name, asset_kind='texture_2d', source_path=f'art_source/hero_camp/{name}.png', runtime_path=f'res://assets/runtime/hero_camp/{name}.png', policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
    write_json(ROOT/'art_source/hero_camp/provenance.json', records)
    path = ROOT/'data/source/resource_bindings.csv'
    current = list(csv.DictReader(path.open(encoding='utf-8')))
    write_csv(path, [r for r in current if not r['id'].startswith('hero_camp.')]+bindings)
    path = ROOT/'data/source/town/town_buildings.csv'
    buildings = list(csv.DictReader(path.open(encoding='utf-8')))
    next(r for r in buildings if r['id']=='building.26')['display_name'] = '英雄营地'
    write_csv(path, buildings)
    print('Hero camp:', len(ART), 'source sprites,', import_levels(), 'levels')


if __name__ == '__main__': main()
