"""Import the four life-building UI details from the supplied APK extraction."""
import csv
import hashlib
import json
import shutil
from pathlib import Path

from import_town_reference import ROOT, read_json, write_csv, write_json

SOURCE = Path('F:/GameResearch/佣兵小镇')
ASSETS = {
    'stats': 'dec0d6c9-b443-4693-bc65-e1f61253d0e7',
    'plus': 'bf4a8286-40ec-49e9-ba3f-a26447ddcc81',
    'price_bonus': 'tmp/life/shenghuo_icon1',
    'time_bonus': 'tmp/life/shenghuo_icon2',
    'seats': 'tmp/life/shenghuo_icon3',
    'badge': '9effb91e-8f62-4032-a210-895d0345a0b9',
    'product_bg': '9c5018e0-de65-40e3-8fe9-ef79b678bc37',
    'product_price': 'c38c255f-5fd2-442e-af89-d14cb2c029b2',
    'tip': 'ee130e8f-3033-47c5-a284-a9f6e1ced5a6',
    'tip_title': 'ed70e6c4-a022-4c95-a216-c55eab135d16',
    'hint': 'e3e92bb6-53db-4368-958b-467c2798b878',
    'progress_bg': '9e35e36c-262d-4d62-9a83-3f68235ad264',
    'progress_blue': '37999128-c18e-43bb-81eb-ad3db0dfea6f',
    'timer_bg': '529a00d5-3a17-4e75-bec6-c5c89c5626e9',
    'timer_green': 'f43b464c-ce0a-4c8a-9f5c-636aec52dfb0',
    'cost_bg': '58d9f1bf-fd98-4da9-914a-bf950d2fcc5f',
    'diamond_bar': '7b36356a-f034-4600-9c24-1bf8d3ce0c6f',
    'help': '14618f68-4445-4fef-8015-b4e92c960acf',
    'diamond': 'tmp/prop/item_money_01',
    'seat_panel': 'da415a77-310e-4e96-9c7a-a61e0aecbf8b',
    'seat_title': 'da415a77-310e-4e96-9c7a-a61e0aecbf8b',
    'seat_row': '97a25de8-a511-4a27-aae0-e79f37c0cc74',
    'buy': '59104aad-5fc6-4aba-9237-58fefa97b83d',
    'report_panel': 'd235096f-89d2-49b8-acae-88a65dfc392d',
    'report_subhead': '1904c31b-fdb2-4a91-b3eb-2d6b5f42e467',
    'acquire_hint': '35e6620a-a15b-417d-a01f-25878fe41743',
    'help_price': '7bb3ace8-c098-47df-84f0-a6d861466190',
    'help_time': '5605cb34-9b29-47a2-adb1-60021be2d24e',
    'acquire_info': '5a511b86-0cf8-42ee-ac46-1d14fc99920a',
    'acquire_row': 'tmp/common/JumpDirectory/bianqiang_diban',
    'acquire_exchange': 'tmp/common/JumpDirectory/bianqiang_icon16',
    'acquire_idle': 'tmp/common/JumpDirectory/bianqiang_icon10',
    'locked': 'e329286b-c013-44c0-b484-7063929a0a5b',
}


def main():
    entries = read_json(SOURCE / '07_核验与索引/精灵切图索引.json')
    lookup = {k: e for e in entries if e['bundle'] == 'resources' for k in (e['name'], e['uuid'])}
    bindings, provenance = [], {}
    for name, key in ASSETS.items():
        entry = lookup[key]
        source = SOURCE / entry['output']
        for directory in ('art_source', 'assets/runtime'):
            target = ROOT / directory / 'life_ui' / (name + '.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        bindings.append(dict(id='life_ui.' + name, asset_kind='texture_2d', source_path=f'art_source/life_ui/{name}.png', runtime_path=f'res://assets/runtime/life_ui/{name}.png', policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
        provenance[name] = dict(source=entry['output'], uuid=entry['uuid'], sha256=hashlib.sha256(source.read_bytes()).hexdigest())
    path = ROOT / 'data/source/resource_bindings.csv'
    rows = list(csv.DictReader(path.open(encoding='utf8')))
    write_csv(path, [r for r in rows if not r['id'].startswith('life_ui.')] + bindings)
    write_json(ROOT / 'art_source/life_ui/provenance.json', provenance)
    cfg = SOURCE / '04_配置表/JSON原表/resources/common/json'
    lang = {r['id']: r['text'] for r in read_json(SOURCE / '04_配置表/JSON原表/resources/common/langconf/c9_lang_chinese_simp.json')}
    path = ROOT / 'data/source/town/town_services.csv'
    services = list(csv.DictReader(path.open(encoding='utf8')))
    prices = read_json(cfg / 'c36_price.json')
    items = {str(r['id']): r for r in read_json(cfg / 'c22_item.json')}
    for index, row in enumerate(services):
        price = prices[index]
        row.update(seat_cost_2=price['limit_price_2'], seat_cost_3=price['limit_price_3'], stat_name=['生命', '饥饿', '疲劳', '心情'][index], seat_title=lang[[9102, 9101, 9104, 9103][index]], price_tip=lang[562+index], time_tip=lang[566+index], seat_tip=lang[570+index], machine_scale=[1.05, 1.02, 1.02, 1.20][index])
        row.update(help_description=lang[2200+index], material_description=lang[items[row['material'].split('.')[1]]['info']])
    write_csv(path, services)
    path = ROOT / 'data/source/town/town_service_levels.csv'
    levels = list(csv.DictReader(path.open(encoding='utf8')))
    source_levels = {f'building.{i+1}': read_json(cfg / f'c36_jz_{name}.json') for i, name in enumerate(['yiyuan','fandian','lvdian','jiudian'])}
    for row in levels:
        row['stage_end'] = str(bool(source_levels[row['building']][int(row['level'])-1]['jd_type'])).lower()
    write_csv(path, levels)
    schema_path = ROOT / 'data/schema/data_schema.json'
    schema = read_json(schema_path)
    additions = {
        'town_services': [(k, 'int') for k in ['seat_cost_2','seat_cost_3']] + [(k,'string') for k in ['stat_name','seat_title','price_tip','time_tip','seat_tip','help_description','material_description']] + [('machine_scale','float')],
        'town_service_levels': [('stage_end','bool')],
    }
    for table, fields in additions.items():
        target = schema['tables'][table]['fields']
        for name, kind in fields:
            if not any(f['name']==name for f in target):
                field = dict(name=name,type=kind,required=True)
                if kind in ['int','float']: field['min'] = 0.01
                target.append(field)
    write_json(schema_path, schema)
    print(f'Imported {len(bindings)} original UI assets and source stage/seat definitions.')


if __name__ == '__main__':
    main()
