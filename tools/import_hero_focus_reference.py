"""Copy source selection artwork without changing pixels or transparent margins."""
import base64
import csv
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE


def main():
    uuids = {'ring': '9941dcf1-c26d-4cde-9bad-5435d5aa2b55', 'detail': '22ddc9f3-93cd-44ad-8bac-db4bc81445d1'}
    # The label frame's full UUID is resolved by its unique compressed prefab UUID.
    value = '3dr6tYZpVM+IZVE3y2679v'
    h = value[:2] + base64.b64decode(value[2:]).hex()
    uuids['label'] = '-'.join([h[:8], h[8:12], h[12:16], h[16:20], h[20:]])
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    with (ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8') as f:
        bindings = [r for r in csv.DictReader(f) if not r['id'].startswith('hero_focus.')]
    sources = {}
    for name, uuid in uuids.items():
        frame = next(row for row in frames if row['uuid'] == uuid)
        original = SOURCE/frame['output']
        paths = [f'art_source/hero_focus/{name}.png', f'assets/runtime/hero_focus/{name}.png']
        for rel in paths:
            target = ROOT/rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, target)
            write_json(target.with_suffix('.png.json'), {'prompt': f'Unmodified original artwork: {original.as_posix()}; Cocos NavigationMainPnl; original transparent canvas retained.'})
        sources[name] = dict(frame=frame, sha256=hashlib.sha256(original.read_bytes()).hexdigest())
        bindings.append(dict(id='hero_focus.'+name, asset_kind='texture_2d', source_path=paths[0], runtime_path='res://'+paths[1], policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
    write_json(ROOT/'art_source/hero_focus/sources.json', sources)
    write_csv(ROOT/'data/source/resource_bindings.csv', bindings)
    print('Imported original hero selection ring and detail button:', len(sources))


if __name__ == '__main__':
    main()
