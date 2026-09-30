"""Import the supplied building UI, numeric definitions and offline Spine inputs."""
import csv
import hashlib
import json
import shutil
from pathlib import Path
from import_town_reference import ROOT, read_json, write_csv, write_json

SOURCE = Path(r'F:\GameResearch\佣兵小镇')
UI = {
    'tier_menu': '1a4d46df-44da-4133-9c84-440dd7745890',
    'building_banner': '1deea7d3-ab12-42b8-bea0-be4bdf6ddc79',
    'condition_banner': '548adf23-b9d6-4dd2-9b16-dd646c11df2c',
    'chain': '86a51799-9146-40ca-9c1e-ced5e57d9de9',
    'hospital_room': 'tmp/life/bj4',
    'canteen_room': 'tmp/life/bj1',
    'hotel_room': 'tmp/life/bj3',
    'bar_room': 'tmp/life/bj2',
    'curtain': 'f08de1d0-f856-43b6-a07e-6ce94d30acca',
    'header': '4855b934-b5c4-4f01-be90-1cae7e90137a',
    'shelf': '20b8c68a-098b-4c4b-bcd8-65073c614f56',
    'desk': 'ae1b7fc0-8922-4954-a753-0acc03f52976',
    'topbar': 'f0808877-eb7e-4e64-9c61-031f88d2b225',
    'money_bg': '68342bf0-3722-424d-a25e-9bf514730612',
    'coin': 'tmp/prop/item_money_00',
    'back': 'e6d82e7f-9557-4b1b-8e09-08aef4128fc5',
    'report': '3519448b-174d-47a0-8682-762b60bf0f4b',
    'upgrade': '693f61cf-4874-4025-9538-4818ed662692',
    'badge': 'ed70e6c4-a022-4c95-a216-c55eab135d16',
    'chair': '83314a72-23e8-47b9-896c-c1b1c64e8568',
    'hourglass': 'tmp/life/shenghuo_icon2',
    'exchange_top': '920cecdc-41d1-4386-bc56-c460a5c93dc5',
    'exchange_title': '0c45da94-75f7-4644-a134-9acc32b1c9fe',
    'exchange_body': '1a313651-536e-4e29-a55b-9489c0eb7149',
    'exchange_bottom': '9caedb34-1022-48e8-a223-199315d2f05b',
    'tab_orders': '09d9c336-f74c-448f-a5b0-81a8051f19b7',
    'tab_heroes': '95089e8e-9d54-40b5-a541-a3c41e82fdd8',
    'item_cell': 'tmp/exchange/jiaoyi_wupinglan',
    'tier': 'tmp/roundIcon/wuqipu_pingjie1',
    'tier_2': 'tmp/roundIcon/wuqipu_pingjie2',
    'dialog': '1edb56cc-8a53-4666-9fe1-f97297d94e6b',
    'confirm': '5c1f5b63-8e3a-49c7-97ce-48382bc20346',
}


def main():
    frames = read_json(SOURCE / '07_核验与索引/精灵切图索引.json')
    by_key = {key: e for e in frames if e['bundle'] == 'resources' for key in [e['name'], e['uuid']]}
    records, bindings = {}, []

    def asset(name, path):
        path = Path(path)
        filename = name + path.suffix
        original, runtime = ROOT / 'art_source/operations' / filename, ROOT / 'assets/runtime/operations' / filename
        for target in [original, runtime]:
            target.parent.mkdir(parents=True, exist_ok=True)
            if path.resolve() != target.resolve():
                shutil.copyfile(path, target)
        aid = 'operations.' + name
        records[aid] = {'source': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        font = path.suffix == '.ttf'
        bindings.append(dict(id=aid, asset_kind='font' if font else 'texture_2d', source_path=original.relative_to(ROOT).as_posix(), runtime_path='res://' + runtime.relative_to(ROOT).as_posix(), policy_id='font_runtime' if font else 'town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
        return aid

    for name, key in UI.items():
        asset(name, SOURCE / by_key[key]['output'])
    for quality in range(1, 6):
        asset(f'quality_{quality}', SOURCE / by_key[f'tmp/quality/wuqipu_pingjie_dikuang00{quality}']['output'])
    asset('font', SOURCE / '03_美术资源/06_粒子材质字体/resources/font/localLib/DefaultFont2.ttf')
    cfg = SOURCE / '04_配置表/JSON原表/resources/common/json'
    lang = {r['id']: r['text'] for r in read_json(SOURCE / '04_配置表/JSON原表/resources/common/langconf/c9_lang_chinese_simp.json')}
    all_items = {r['id']: r for r in read_json(cfg / 'c22_item.json')}
    trade = sorted([r for r in read_json(cfg / 'c41_trade.json') if r['lv'] <= 2], key=lambda r: (r['lv'], r['no']))
    items = []
    for i, entry in enumerate(trade + [dict(item_id=n, max_num=0, lv=1) for n in [20151,20152,20153,20154]]):
        r = all_items[entry['item_id']]
        items.append(dict(id=f'item.{r["id"]}', display_name=lang.get(r['name'], r['remark2']), resource_id=asset(f'item_{r["id"]}', SOURCE / by_key[f'tmp/prop/{r["id"]}']['output']), buy_price=r['buy_price'], sell_price=r['sell_price'], quality=r['quality'], order_limit=entry['max_num'], tier=entry['lv'], sort_order=i))
    write_csv(ROOT / 'data/source/town/town_items.csv', items)
    services, levels = [], []
    for number, key, stat, table, product in [(1,'hospital','hp','yiyuan',20151),(2,'canteen','energy','fandian',20152),(3,'hotel','tired','lvdian',20154),(4,'bar','mood','jiudian',20153)]:
        recipe = next(r for r in read_json(cfg / 'c37_shenghuo_xiaohao.json') if r['id'] == product)
        material, count = map(int, recipe['consume'].split(':'))
        services.append(dict(id=f'building.{number}', display_name={1:'医院',2:'餐馆',3:'旅馆',4:'酒馆'}[number], stat=stat, material=f'item.{material}', product=f'item.{product}', material_cost=count, service_seconds=float(recipe['replay_time']), recovery_ratio=recipe['replay_num'][0]/10000, room=f'operations.{key}_room', machine=f'operations.{key}_idle'))
        filename = cfg / f'c36_jz_{table}.json'
        if not filename.exists():
            raise FileNotFoundError(filename)
        for r in read_json(filename)[:40]:
            levels.append(dict(id=f'{key}.{r["id"]}', building=f'building.{number}', level=r['id'], cost=int(r['xh'].split(':')[1]), bonus=r['price']/10000, seats=r['hero_num'], reduction=float(r['js_time']), city_level=int(r['tj'].strip(';').split(':')[1])))
    write_csv(ROOT / 'data/source/town/town_services.csv', services)
    write_csv(ROOT / 'data/source/town/town_service_levels.csv', levels)
    equipment = {r['id']: r for r in read_json(cfg / 'c39_zhuangbei.json')}
    recipes = []
    owners = {60201:10,70201:10}
    for r in read_json(cfg / 'c51_tuzhi.json'):
        if r['id'] not in owners:
            continue
        eq = equipment[r['zb_1']]
        (mat_a, num_a), (mat_b, num_b) = r['consume']
        recipes.append(dict(id=f'forge.{r["id"]}', building=f'building.{owners[r["id"]]}', display_name=lang[eq['name']], resource_id=asset(f'equip_{eq["id"]}',SOURCE / by_key[f'tmp/eqicon/{eq["icon"]}']['output']), material_a=f'item.{mat_a}', count_a=num_a, material_b=f'item.{mat_b}', count_b=num_b, price=eq['basic_g'], job=eq['job'], slot=eq['buwei'], attribute=eq['sx'][0][0], power=eq['sx'][0][1], quality=eq['pinzhi']))
    write_csv(ROOT / 'data/source/town/town_equipment.csv', recipes)
    spine = read_json(SOURCE / '07_核验与索引/Spine索引.json')
    selections = [('hospital', 'ae015aac-9575-4c06-a6b8-4f856ea129c8')]
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    def expand(s):
        if len(s) != 22:
            return s
        h = s[:2]
        for i in range(2,22,2):
            a,b = alphabet.index(s[i]),alphabet.index(s[i+1]); h += f'{a>>2:x}{((a&3)<<2)|(b>>4):x}{b&15:x}'
        return f'{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}'
    for key, prefab in [('canteen','Catten'),('hotel','Hotel'),('bar','Bar')]:
        d = read_json(SOURCE / f'03_美术资源/04_预制体/resources/view/life/node{prefab}Produce.json')
        candidates = [e for e in spine if e['uuid'] in [expand(u) for u in d[1]]]
        selections.append((key, candidates[0]['uuid']))
    jobs = []
    for name, uuid in selections:
        entry = next(e for e in spine if e['uuid'] == uuid)
        skeleton = SOURCE / entry['output']
        directory = ROOT / 'art_source/operations/spine' / name
        directory.mkdir(parents=True, exist_ok=True)
        for path in skeleton.parent.iterdir():
            if path.suffix in ['.png', '.atlas', '.json', '.skel']:
                if path.suffix in ['.json', '.atlas']:
                    (directory / path.name).write_text(path.read_text(encoding='utf-8-sig'), encoding='utf8', newline='\n')
                else:
                    shutil.copyfile(path, directory / path.name)
        jobs.append(dict(name=name, skeleton=(directory / skeleton.name).relative_to(ROOT).as_posix(), animation='idle', width=512, height=640, frames=8))
        for suffix in ['idle']:
            baked = ROOT / f'art_source/operations/{name}_{suffix}.png'
            if baked.exists():
                asset(f'{name}_{suffix}', baked)
    write_json(ROOT / 'art_source/operations/bake_jobs.json', jobs)
    binding_file = ROOT / 'data/source/resource_bindings.csv'
    previous = [r for r in csv.DictReader(binding_file.open(encoding='utf8')) if not r['id'].startswith('operations.')]
    write_csv(binding_file, previous + bindings)
    write_json(ROOT / 'art_source/operations/provenance.json', {'reference_root': str(SOURCE), 'assets': records, 'bake': 'PixiJS 7.4.3 + pixi-spine 4.0.6; 8 frames; transparent PNG'})
    print(f'Imported {len(bindings)} assets and {len(items)} item definitions.')


if __name__ == '__main__':
    main()
    from import_life_ui_reference import main as import_life_details
    import_life_details()
