"""Read-only reference extraction for named heroes, wilderness and navigation."""
import hashlib
import csv
import shutil
from pathlib import Path
from import_town_reference import ROOT, read_json, write_csv, write_json

SOURCE = Path('F:/GameResearch/佣兵小镇')
CFG = SOURCE / '04_配置表/JSON原表/resources/common/json'

# Stable identities of the three original actors.
INITIAL = {32008: ('abbi', 'hero.1', 5000, 320, 85), 11006: ('terence', 'hero.2', 6500, 340, 125), 22006: ('barbara', 'hero.3', 4800, 350, 80)}
RIGS = {
    (1, 1): ('master/boy', 'zhanshi', 'zhanshibei', 'spine_warrior_male'),
    (1, 2): ('master/girl', 'nvzhanshi', 'nvzhenshibei', 'spine_warrior_female'),
    (2, 1): ('archar/boy', 'nangongjianshou', 'nangongjianshoubei', 'spine_archar_male'),
    (2, 2): ('archar/girl', 'nvgongjianshou', 'nvgongjianshoubei', 'spine_archar_female'),
    (3, 1): ('magic/boy', 'nanfashi', 'fashibei', 'spine_magic_male'),
    (3, 2): ('magic/girl', 'nvfashi', 'nvfashibei', 'spine_magic_female'),
}


def selected_heroes():
    with (ROOT/'data/source/town/main_heroes.csv').open(encoding='utf-8') as stream:
        catalog = {int(r['appearance']): r for r in csv.DictReader(stream)}
    ids = list(INITIAL) + [12003, 21001, 32002]
    for quality, count in [(3, 4), (4, 5), (5, 5)]:
        for job in [1, 2, 3]:
            candidates = sorted(i for i, r in catalog.items() if int(r['quality']) == quality and int(r['job']) == job)
            assert len(candidates) >= count, (quality, job)
            ids.extend(candidates[:count])
    assert len(ids) == len(set(ids)) == 48
    # Keep the established actor identities/order, and support every existing recruit.
    ids.extend(sorted(set(catalog) - set(ids)))
    return [catalog[i] for i in ids]


def main():
    spine = read_json(SOURCE/'07_核验与索引/Spine索引.json')
    jobs = []
    appearances = {x['id']:x for x in read_json(CFG/'c25_zww.json')}
    heroes = []
    talents = {r['id']: r for r in read_json(CFG/'c29_tf2.json')}
    for i, hero in enumerate(selected_heroes()):
        zww, job = int(hero['appearance']), int(hero['job'])
        appearance = appearances[zww]
        folder, front, back, table = RIGS[job, appearance['sex']]
        talent = talents[int(hero['source_id'])]
        key, identity, hp, attack, defense = INITIAL.get(zww, (f'hero_{zww}', f'hero.{zww}', float(hero['hp']) + talent['hp'], float(hero['attack']) + talent['att'], float(hero['defense']) + talent['def']))
        heroes.append(dict(id=identity,display_name=hero['display_name'],visual=key,job=job,level=1,source_appearance=zww,wallet=150000,hp=100,max_hp=hp,attack=attack,defense=defense,start_delay=i*0.8,initially_owned=str(zww in INITIAL).lower()))
        config = {x['id']:x for x in read_json(CFG/(table+'.json'))}
        for direction,basename in [('front',front),('back',back)]:
            entry = next(x for x in spine if x['name']==f'tmp/role/hero/{folder}/{direction}/{basename}')
            skin = config[4 if direction=='front' else 10]['slot_'+str(appearance['body'])]
            hidden=[]
            for part,choice in ([(5,appearance['head']),(6,appearance['face']),(7,appearance['face'])] if direction=='front' else [(11,appearance['head'])]):
                row=config[part]
                for n in range(row['num']):
                    if n!=choice or part==7:
                        hidden.extend(row.get(f'slot_{n}','').split(';'))
            record=copy_spine(entry,table,direction,skin,[s for s in hidden if s])
            record['name'] = key
            record['appearance'] = zww
            record['parts'] = {part: appearance[part] for part in ['head','face','body']}
            record['weapon_slots']={str(p):config[p]['slot_0'] for p in ([1,2,3] if direction=='front' else [8,9])}
            jobs.append(record)
    write_csv(ROOT/'data/source/town/town_heroes.csv',heroes)
    monsters=[]
    for key,number,folder,base in [('wolf',1,'Langren','langren'),('bear',2,'Xiongren','xiongren')]:
        row=next(x for x in read_json(CFG/'c2_guaiwu.json') if x['id']==number)
        loot=next(x for x in read_json(CFG/'c2_guaiwu_drop.json') if x['id']==number)
        monsters.append(dict(id=key,display_name=row['remark'],visual=key,max_hp=row['hp'],attack=row['att'],defense=row['def'],attack_range=100,speed=110,respawn_seconds=10,coins=loot['jinbi']))
        for direction,suffix in [('front',''),('back','bei')]:
            entry=next(x for x in spine if x['name']==f'tmp/role/monster/{folder}/{base}{suffix}')
            jobs.append(copy_spine(entry,key,direction,'',[]))
    write_csv(ROOT/'data/source/town/town_monsters.csv',monsters)
    write_json(ROOT/'art_source/heroes/bake_jobs.json',jobs)
    actor_ui()
    schema()
    from import_field_reference import main as field_reference
    field_reference()
    from import_combat_reference import main as combat_reference
    combat_reference()
    from import_navigation_reference import main as navigation_reference
    navigation_reference()
    from import_loot_reference import main as loot_reference
    loot_reference()


def actor_ui():
    frames=read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    records={}
    for name,uuid in [('health_track','1c7cabb8-b2c8-412f-b001-ba3fdb59be30'),('monster_health_track','e341e0f5-4a57-4d75-89b6-42b88a23d649'),('health_fill','ea139d5a-1ba9-4fe4-b5bf-a487d44226a7'),('level_badge','eb149b61-e545-4f73-bd86-333f2765bec6'),('hero_shadow','1395faa3-3d25-44ad-8d00-061daaa8e220')]:
        row=next(r for r in frames if r['uuid']==uuid)
        source=SOURCE/row['output']
        target=ROOT/f'art_source/heroes/ui/{name}.png'
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
        records[name]=dict(source=row['output'],sha256=hashlib.sha256(source.read_bytes()).hexdigest(),uuid=uuid)
    write_json(ROOT/'art_source/heroes/ui_sources.json',records)


def copy_spine(entry,key,direction,skin,hidden):
    skeleton=SOURCE/entry['output']
    folder=ROOT/'art_source/heroes/spine'/key/direction
    folder.mkdir(parents=True,exist_ok=True)
    for p in skeleton.parent.iterdir():
        if p.suffix in ['.json','.skel','.atlas','.png']:
            if p.suffix in ['.json', '.atlas']:
                (folder/p.name).write_text(p.read_text(encoding='utf-8-sig'), encoding='utf-8', newline='\n')
            else:
                shutil.copyfile(p,folder/p.name)
    return dict(name=key,direction=direction,skeleton=(folder/skeleton.name).relative_to(ROOT).as_posix(),skin=skin,hidden=hidden,source=entry['output'],sha256=hashlib.sha256(skeleton.read_bytes()).hexdigest())


def schema():
    target=ROOT/'data/schema/data_schema.json'; d=read_json(target)
    def field(name,kind='string',**opts): return dict(name=name,type=kind,required=True,**opts)
    def table(name,fields): d['tables'][name]=dict(source=f'town/{name}.csv',**{'class':'definition'},primary_key=['id'],fields=[field('id','id')]+fields)
    table('town_heroes',[field('display_name'),field('visual'),field('job','int',min=1,max=3),field('level','int',min=1),field('source_appearance','int',min=1),field('wallet','int',min=0),field('hp','float',min=0,max=100)]+[field(x,'float',min=0.01) for x in ['max_hp','attack','defense']]+[field('start_delay','float',min=0),field('initially_owned','bool')]+[field(x,'float',min=0.01) for x in ['attack_range','speed']])
    table('town_monsters',[field('display_name'),field('visual')]+[field(x,'float',min=0.01) for x in ['max_hp','attack','defense','attack_range','speed','respawn_seconds']]+[field('coins','int',min=0)])
    table('town_animations',[field('actor'),field('direction','enum',values=['front','back']),field('action','enum',values=['idle','move','attack','death']),field('resource_id','ref',table='resource_bindings',field='id'),field('frames','int',min=1),field('seconds','float',min=0.01)]+[field(n,'int',min=1,max=4096) for n in ['columns','rows','frame_width','frame_height']])
    write_json(target,d)


if __name__=='__main__':
    main()
