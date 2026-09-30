"""Import supplied map artwork and placements; never changes the reference folder."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD_PREFABS = dict(zip(
    [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 16, 20, 25, 26, 27],
    ['Hospital', 'Canteen', 'Hotel', 'Bar', 'MainCity', 'WeaponShop', 'Exchange',
     'ArmorShop', 'OrnamentShop', 'Resurgence', 'BossSummon', 'Intensify', 'Pve',
     'ZhuanSheng', 'Train', 'Summon', 'Apartment', 'Knowledge']))
BARRIER_PREFABS = dict(enumerate([
    'WeedGrass', 'Bush', 'Stump', 'FlowerRick', 'Bushes', 'AncientTree',
    'Stone', 'House', 'Courtyard', 'Tong', 'XiangZiSun', 'XiangZiBlack'], 1))


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def prefab_offset(path):
    data = read_json(path)
    nodes = []
    for row in data[5]:
        mask = data[4][row[0]]
        cls = data[3][mask[0]]
        nodes.append(dict(zip((cls[1][i] for i in mask[1:-1]), row[1:])))
    sprite = next(n for n in nodes if n.get('_name') == 'img_building')
    x, y = 0.0, 0.0
    node = sprite
    while node is not nodes[1]:
        trs = node.get('_trs', [0, 0, 0, 0, 0, 0, 1, 1, 1, 1])
        if trs[7:9] != [1, 1]:
            raise ValueError(f'Unexpected scaled sprite: {path}')
        x += trs[0]
        y += trs[1]
        node = nodes[node['_parent']]
    return x, -y


def import_reference(source):
    entries = [v for v in read_json(source / '07_核验与索引/精灵切图索引.json') if v['bundle'] == 'resources']
    frames = {}
    for entry in entries:
        if entry['name'].startswith(('tmp/build/', 'tmp/disassembly/', 'tmp/map/common/')):
            key = entry['name'].split('/')[-1]
            if key in frames:
                raise ValueError(f'Ambiguous resource name: {key}')
            frames[key] = entry
    cfg = source / '04_配置表/JSON原表/resources/common/json'
    prefabs = source / '03_美术资源/04_预制体/resources/view'
    records, bindings = {}, []
    def copy_asset(name, rel=None):
        asset_id = 'town.' + name.lower()
        if asset_id in records:
            return asset_id
        external = source / (rel or frames[name]['output'])
        filename = name + external.suffix
        original = ROOT / 'art_source/town' / filename
        runtime = ROOT / 'assets/runtime/town' / filename
        for target in [original, runtime]:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(external, target)
        records[asset_id] = dict(source=external.relative_to(source).as_posix(), sha256=hashlib.sha256(external.read_bytes()).hexdigest())
        font = external.suffix == '.ttf'
        bindings.append(dict(id=asset_id, asset_kind='font' if font else 'texture_2d', source_path=original.relative_to(ROOT).as_posix(), runtime_path='res://' + runtime.relative_to(ROOT).as_posix(), policy_id='font_runtime' if font else 'town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
        return asset_id
    def offsets(name, center):
        ox, oy = frames[name]['offset']
        return round(center[0] - ox, 3), round(center[1] + oy, 3)
    buildings = []
    for row in read_json(cfg / 'c33_jianzhu.json'):
        center = prefab_offset(prefabs / f"build/Building{BUILD_PREFABS[row['id']]}Prefab.json")
        built = row['png_path']
        before = row['png_path_rebuild']
        bx, by = offsets(built, center)
        rx, ry = offsets(before, center) if before else (bx, by)
        buildings.append(dict(id=f"building.{row['id']}", display_name=row['remark'], grid_x=row['x'], grid_y=row['y'], width=row['grid_width'], height=row['grid_height'], built_resource=copy_asset(built), before_resource=copy_asset(before) if before else '', built_offset_x=bx, built_offset_y=by, before_offset_x=rx, before_offset_y=ry, initially_built=str(not row['rebuild']).lower()))
    scenery = []
    for table, seat, key, prefix in [('c33_jianzhu_zaw', 'c33_zaw_seat', 'zaw_id', 'barrier'), ('c33_jianzhu_zs', 'c33_zsw_seat', 'zsw_id', 'ornament')]:
        definitions = {r['id']: r for r in read_json(cfg / (table + '.json'))}
        for place in read_json(cfg / (seat + '.json')):
            row = definitions[place[key]]
            name = row['png_path']
            if prefix == 'barrier':
                prefab = f"disassembly/barrier/Barrier{BARRIER_PREFABS[row['id']]}Prefab.json"
            elif row['id'] < 200:
                kind = {101: 'HeroStone', 111: 'SmallTree', 112: 'BigTree'}[row['id']]
                prefab = f'disassembly/ornament/Ornament{kind}Prefab.json'
            else:
                prefab = f"disassembly/ornament/OrnamentRoad{row['id'] - 199:03}Prefab.json"
            center = prefab_offset(prefabs / prefab)
            ox, oy = offsets(name, center)
            scenery.append(dict(id=f"{prefix}.{place['id']}", resource_id=copy_asset(name), grid_x=place['X'], grid_y=place['Y'], offset_x=ox, offset_y=oy, layer='ground' if prefix == 'ornament' and row['id'] >= 200 else 'objects', height=row['grid_height']))
    backgrounds = [dict(id=f'background.{i}', resource_id=copy_asset(f'bg{i}'), x=((i-1) % 3) * 2066, y=((i-1) // 3) * 2427) for i in range(1, 7)]
    for name, rows in [('town_buildings', buildings), ('town_scenery', scenery), ('town_backgrounds', backgrounds)]:
        write_csv(ROOT / f'data/source/town/{name}.csv', rows)
    binding_path = ROOT / 'data/source/resource_bindings.csv'
    with binding_path.open(encoding='utf-8', newline='') as f:
        previous = [r for r in csv.DictReader(f) if not r['id'].startswith('town.')]
    write_csv(binding_path, previous + bindings)
    write_json(ROOT / 'art_source/town/provenance.json', dict(reference_root=str(source), purpose='用户提供的小镇地图原型参考资源', assets=records))
    print(f'Imported {len(records)} assets, {len(buildings)} buildings, {len(scenery)} scenery placements.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    import_reference(parser.parse_args().source.resolve())
