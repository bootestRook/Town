"""Import field loot, pickup art and timing from the supplied APK archive."""
import csv
import hashlib
import shutil
import subprocess
from import_hero_reference import SOURCE, CFG
from import_town_reference import ROOT, read_json, write_csv, write_json


def rows(path):
    with path.open(encoding='utf-8') as stream:
        return list(csv.DictReader(stream))


def main():
    schema = read_json(ROOT/'data/schema/data_schema.json')
    def field(name, kind, **extra):
        return dict(name=name, type=kind, required=True, **extra)
    def table(name, records, fields):
        schema['tables'][name] = dict(source=f'town/{name}.csv', **{'class': 'definition'}, primary_key=['id'], fields=[field('id', 'id')] + fields)
        write_csv(ROOT/f'data/source/town/{name}.csv', records)
    source_drops = {r['id']: r for r in read_json(CFG/'c2_guaiwu_drop.json')}
    monsters = rows(ROOT/'data/source/town/town_monsters.csv')
    drops = []
    for monster in monsters:
        source_id = int(monster['source_id'])
        source = source_drops[source_id]
        mutant = monster['mutant']=='true'
        monster['experience'] = source['bianyi_exp' if mutant else 'exp']
        for recipient in ['hero', 'ground']:
            for token in source[('bianyi_' if mutant else '')+'drop_'+recipient].split(';'):
                item, chance, minimum, maximum = map(int, token.split('|'))
                drops.append(dict(id=f'{monster["id"]}.{recipient}.{item}', monster=monster['id'], recipient=recipient, item=f'item.{item}', chance=chance, minimum=minimum, maximum=maximum))
    fields = schema['tables']['town_monsters']['fields']
    fields[:] = [f for f in fields if f['name'] != 'experience'] + [field('experience', 'int', min=0)]
    write_csv(ROOT/'data/source/town/town_monsters.csv', [{f['name']:r[f['name']] for f in fields} for r in monsters])
    table('town_drops', drops, [field('monster','ref',table='town_monsters',field='id'),field('recipient','enum',values=['hero','ground']),field('item','ref',table='town_loot_items',field='id'),field('chance','int',min=0,max=10000),field('minimum','int',min=1),field('maximum','int',min=1)])
    horns = rows(ROOT/'data/source/town/main_horn_levels.csv')
    for horn in horns:
        horn['experience'] = source_drops[int(horn['monster_id'])]['exp']
    fields = schema['tables']['main_horn_levels']['fields']
    fields[:] = [f for f in fields if f['name'] != 'experience'] + [field('experience','int',min=0)]
    write_csv(ROOT/'data/source/town/main_horn_levels.csv', [{f['name']:r[f['name']] for f in fields} for r in horns])
    wanted = {int(r['item'].split('.')[1]) for r in drops}
    for horn in horns:
        for recipient in ['hero','ground']:
            wanted.update(int(t.split('|')[0]) for t in horn['drop_'+recipient].split(';') if t)
    item_defs = {r['id']:r for r in read_json(CFG/'c22_item.json')}
    lang = {r['id']:r['text'] for r in read_json(CFG.parent/'langconf/c9_lang_chinese_simp.json')}
    frames = {r['name']:r for r in read_json(SOURCE/'07_核验与索引/精灵切图索引.json') if r['bundle']=='resources'}
    bindings = [r for r in rows(ROOT/'data/source/resource_bindings.csv') if not r['id'].startswith('loot.')]
    provenance = {}
    def asset(name, key):
        original = SOURCE/frames[key]['output']
        provenance[name] = dict(source=frames[key]['output'], uuid=frames[key]['uuid'], sha256=hashlib.sha256(original.read_bytes()).hexdigest())
        for base in ['art_source','assets/runtime']:
            target = ROOT/base/'loot'/f'{name}.png'
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original,target)
            write_json(target.with_suffix('.png.json'), dict(prompt='Original source game asset, unchanged pixels; '+frames[key]['output']))
        bindings.append(dict(id='loot.'+name,asset_kind='texture_2d',source_path=f'art_source/loot/{name}.png',runtime_path=f'res://assets/runtime/loot/{name}.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
        return 'loot.'+name
    items = []
    for item in sorted(wanted):
        row = item_defs[item]
        items.append(dict(id=f'item.{item}',source_id=item,display_name=lang[row['name']],quality=row['quality'],max_count=row['max_num'],resource_id=asset(f'item_{item}','tmp/prop/'+row['pic'].removesuffix('.png')),tier=row['grade'],sort_order=item,order_limit=0,buy_price=row['buy_price'],sell_price=row['sell_price']))
    table('town_loot_items',items,[field('source_id','int',min=1),field('display_name','string'),field('quality','int',min=1),field('max_count','int',min=1),field('resource_id','ref',table='resource_bindings',field='id')]+[field(n,'int',min=0) for n in ['tier','sort_order','order_limit','buy_price']]+[field('sell_price','int',min=-1)])
    for quality in range(1,6):
        asset('glow_'+str(quality),'tmp/drop/diaoluo_guang'+str(quality))
    public = {r['id']:r['value'] for r in read_json(CFG.parent/'baseconf/c25_public.json')}
    table('town_loot_rules',[dict(id='loot',normal_seconds=int(public[1122]),boss_seconds=int(public[1131]))],[field('normal_seconds','int',min=1),field('boss_seconds','int',min=1)])
    levels = read_json(CFG/'c16_lv_up.json')[:100]
    table('town_hero_levels',[dict(id='level.'+str(r['id']),level=r['id'],experience=r['exp_num']) for r in levels],[field('level','int',min=1,max=100),field('experience','int',min=1)])
    audio = next(r for r in read_json(CFG.parent/'baseconf/c5_base_audio.json') if r['id']==50)
    original = SOURCE/'05_音频/resources/sound'/(audio['path']+'.mp3')
    target = ROOT/'art_source/loot/pickup.wav'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(original),str(target)],check=True)
    shutil.copyfile(target,ROOT/'assets/runtime/loot/pickup.wav')
    provenance['pickup'] = dict(source=original.relative_to(SOURCE).as_posix(),sha256=hashlib.sha256(original.read_bytes()).hexdigest())
    bindings.append(dict(id='loot.pickup',asset_kind='audio',source_path='art_source/loot/pickup.wav',runtime_path='res://assets/runtime/loot/pickup.wav',policy_id='audio_stream',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    write_csv(ROOT/'data/source/resource_bindings.csv',bindings)
    write_json(ROOT/'data/schema/data_schema.json',schema)
    for path in [CFG/'c2_guaiwu_drop.json',CFG/'c22_item.json',CFG/'c16_lv_up.json',CFG.parent/'baseconf/c25_public.json']:
        provenance[path.stem] = dict(source=path.relative_to(SOURCE).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    write_json(ROOT/'art_source/loot/provenance.json',provenance)
    print(f'Loot: {len(drops)} drop rows, {len(items)} item definitions, source lifetimes 60/300 seconds')


if __name__ == '__main__':
    main()
