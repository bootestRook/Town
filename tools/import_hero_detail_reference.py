"""Import the original HeroPartPnl sprites and skill icons, without changing the APK dump."""
import csv
import base64
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG


def main():
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup = {key: r for r in frames for key in (r['name'], r['uuid'], r['frame_name'])}
    bindings, provenance = [], {}

    def add(name, key, register_texture=True):
        row = lookup[key]
        original = SOURCE/row['output']
        record = {'source': row['output'], 'uuid': row['uuid'], 'sha256': hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/hero_detail', 'assets/runtime/hero_detail']:
            target = ROOT/directory/(name+'.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, target)
            write_json(target.with_suffix('.png.json'), {'prompt': 'Original Mercenary Town sprite; not AI generated.', 'source': record})
        if register_texture:
            bindings.append(dict(id='hero_detail.'+name, asset_kind='texture_2d', source_path='art_source/hero_detail/'+name+'.png', runtime_path='res://assets/runtime/hero_detail/'+name+'.png', policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
        provenance[name] = record

    assets = {
        'power': '78130bf1-b468-4241-a871-0e06ea885371',
        'magic': '6f67f658-5dd7-4b02-9055-5e7f894bdef8',
        'hunger': 'e4602f0a-ee4c-4aa1-b76e-8a3cae7d8625',
        'tired': '32b22d0b-be48-45d8-874a-74fa543a3450',
        'mood': '3da37aa0-33cd-4b9b-aa89-ec078b4b4207',
        'hp': 'c67f8dea-ca26-42c7-a362-d91da454ce14',
        'attack': '5d531eac-ad95-4225-aa49-4b78a5f5c577',
        'defense': 'f0b6f76f-7db8-48a7-9cb8-cde5b805904d',
        'info': 'e0733f82-b60d-44b5-8d0e-73e9b1ad9ce3',
        'tip_title': 'ed70e6c4-a022-4c95-a216-c55eab135d16',
        'tip_body': 'ee130e8f-3033-47c5-a284-a9f6e1ced5a6',
        'body': '1a313651-536e-4e29-a55b-9489c0eb7149',
        'change': '4cc9a949-e08e-453a-9370-9fa01b46020e',
        'wallet': 'd519f19a-56a4-43e6-97f2-f4878e2f0274',
        'top': 'f0808877-eb7e-4e64-9c61-031f88d2b225',
        'gold': '91c657f4-68e3-4622-bba5-7d4e0e527960',
        'diamonds': '1f582b14-5e47-4b87-92e1-8526a5ecd6c1',
        'arrow': '3af1061e-5c3a-45b5-a848-b81f2b429ea7',
        'bottom': '9caedb34-1022-48e8-a223-199315d2f05b',
        'back': 'e6d82e7f-9557-4b1b-8e09-08aef4128fc5',
        'tab_0_selected': '42a94168-0569-439a-844c-e672a6608b2d',
        'tab_0': '51f6e2f3-44d6-40fc-95e5-a3faa3b6e572',
        'tab_1_selected': 'b9b5ce62-57d9-49e5-9174-10dd9a42e089',
        'tab_1': '5280f1c0-b401-4e19-8477-65201afff006',
        'tab_2_selected': '0951464f-c76f-4c25-ab57-0c11e7e13825',
        'tab_2': '7cf423c8-ce90-40c0-934b-488ec5a25f61',
        'tab_3_selected': '1f735666-9040-484c-96ed-c641bbdcd916',
        'tab_3': '8790f3bf-529b-478c-b11c-6459ed129987',
        'skills_body': 'c16f1461-8ba7-4208-983d-df01c6d535df',
        'star_button': '074ee034-010c-4d39-8cdc-1772bb2a33d1',
        'cost': '9f9c7bb2-aff9-4eed-bc1f-bb5a0be6622e',
        'rank': 'tmp/roundIcon/yingxiong_pinjie1',
        'equipment_settings': 'fed39c10-cc2e-4907-a5fd-cb2995ae6cfc',
        'skill_frame': '928ca8c2-694e-49c8-b9dc-2e915e3d01ab',
        'skill_level': 'be738989-1a74-4d9b-9812-72480dbed4f0',
        'skill_lock': '4e2ceabc-d437-4e60-ba85-bb9f08ebb870',
    }
    for i in range(1, 6): assets['background_'+str(i)] = 'tmp/common/common_beijing_'+str(i)
    for i in range(1, 9): assets['empty_'+str(i)] = 'tmp/eqicon/third/zhuangbei_0'+str(i)
    for name, key in assets.items(): add(name, key)
    font_source = SOURCE/'03_美术资源/06_粒子材质字体/resources/__未命名/e4dcc525-eb7b-417d-a092-3fc66b28d6d1.json'
    font_data = read_json(font_source)
    compressed = font_data[1][0]
    hex_id = compressed[:2] + base64.b64decode(compressed[2:]+'==').hex()
    atlas_uuid = '-'.join([hex_id[:8],hex_id[8:12],hex_id[12:16],hex_id[16:20],hex_id[20:]])
    # The BMFont importer owns its page image and marks that image as skipped.
    add('power_font', atlas_uuid, register_texture=False)
    config = font_data[5][0][3]
    glyphs = config['fontDefDictionary']
    width, height = lookup[atlas_uuid]['rect'][2:]
    lines = ['info face="zhandouli" size=36 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0', f'common lineHeight=36 base=36 scaleW={width} scaleH={height} pages=1 packed=0', 'page id=0 file="power_font.png"', f'chars count={len(glyphs)}']
    for char, glyph in glyphs.items():
        r = glyph['rect']
        lines.append(f'char id={char} x={r["x"]} y={r["y"]} width={r["width"]} height={r["height"]} xoffset={glyph["xOffset"]} yoffset={glyph["yOffset"]} xadvance={glyph["xAdvance"]-5} page=0 chnl=15')
    for directory in ['art_source/hero_detail', 'assets/runtime/hero_detail']:
        (ROOT/directory/'power.fnt').write_text('\n'.join(lines)+'\n', encoding='utf-8', newline='\n')
    bindings.append(dict(id='hero_detail.power_font_face', asset_kind='font', source_path='art_source/hero_detail/power.fnt', runtime_path='res://assets/runtime/hero_detail/power.fnt', policy_id='font_runtime', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
    provenance['power_font_face'] = {'source': str(font_source.relative_to(SOURCE)), 'conversion': 'Cocos BitmapFont to BMFont; source rects, baked colors and spacingX=-5 preserved'}
    skill_rows = []
    # Four hero slots are skill1..4; the first talent token is the separate basic attack.
    used = {int(token.split(';')[0]) for r in csv.DictReader((ROOT/'data/source/town/main_talents.csv').open(encoding='utf-8')) for token in r['skills'].split('|')[1:]}
    for row in read_json(CFG/'skill_base.json') + read_json(CFG/'skill_passive.json') + read_json(CFG/'skill_buff.json'):
        if row['id'] not in used: continue
        add('skill_'+str(row['id']), 'tmp/skillIcon/'+row['pic'])
        skill_rows.append({'id': 'skill_art.'+str(row['id']), 'source_id': row['id'], 'resource_id': 'hero_detail.skill_'+str(row['id'])})
    assert {r['source_id'] for r in skill_rows} == used
    write_csv(ROOT/'data/source/town/main_skill_art.csv', skill_rows)
    schema = read_json(ROOT/'data/schema/data_schema.json')
    schema['tables']['main_skill_art'] = {'source': 'town/main_skill_art.csv', 'class': 'definition', 'primary_key': ['id'], 'fields': [{'name': 'id', 'type': 'id', 'required': True}, {'name': 'source_id', 'type': 'int', 'required': True}, {'name': 'resource_id', 'type': 'ref', 'table': 'resource_bindings', 'field': 'id', 'required': True}]}
    write_json(ROOT/'data/schema/data_schema.json', schema)
    previous = [r for r in csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8')) if not r['id'].startswith('hero_detail.')]
    write_csv(ROOT/'data/source/resource_bindings.csv', previous+bindings)
    write_json(ROOT/'art_source/hero_detail/provenance.json', provenance)
    print('Imported hero detail sprites:', len(bindings), 'skills:', len(skill_rows))


if __name__ == '__main__': main()
