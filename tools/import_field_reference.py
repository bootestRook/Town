"""Import first-world regional densities, original spawn points and all nine monster rigs."""
import csv, hashlib, math
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG, copy_spine


def main():
    from import_navigation_reference import objects
    lang = {r['id']:r['text'] for r in read_json(CFG.parent/'langconf/c9_lang_chinese_simp.json')}
    source_monsters = {r['id']:r for r in read_json(CFG/'c2_guaiwu.json')}
    models = {r['name']:r for r in read_json(CFG/'c59_guaiwu_model.json')}
    drops = {r['id']:r for r in read_json(CFG/'c2_guaiwu_drop.json')}
    public = {r['id']:float(r['value']) for r in read_json(CFG.parent/'baseconf/c25_public.json') if r['id'] in [1041,1042]}
    identities = {i: ('wolf' if i==1 else 'bear' if i==2 else source_monsters[i]['pic'].lower()) for i in range(1,10)}
    monsters=[]
    for number,key in identities.items():
        r=source_monsters[number];area='field'+(str((number-1)//3+1) if number>3 else '')
        for mutant in ([False,True] if r['type']==1 else [False]):
            monsters.append(dict(id=key+('.mut' if mutant else ''),display_name=lang[int(r['name_jy_id'])] if mutant else lang[r['name_id']],visual=key,max_hp=r['hp_jy'] if mutant else r['hp'],attack=r['att'],defense=r['def'],attack_range=100,speed=r['speed']*public[1042],respawn_seconds=12 if number>6 else 10,coins=drops[number]['jinbi'],city_speed=r['speed']*public[1041],patrol_range=r['search_range'],experience=drops[number]['bianyi_exp' if mutant else 'exp'],source_id=number,area=area,mutant=str(mutant).lower(),skill=r['skl_pg'],appearance=r['pic']))
    write_csv(ROOT/'data/source/town/town_monsters.csv',monsters)
    prefab=SOURCE/'03_美术资源/04_预制体/resources/view/map/Map.json'
    packed=read_json(prefab); nodes=[]
    for raw in packed[5]:
        mask=packed[4][raw[0]];nodes.append(dict(zip([packed[3][mask[0]][1][i] for i in mask[1:-1]],raw[1:])))
    levels=[];members=[];spawns=[];configs=[]
    for number in range(1,4):
        area='field'+(str(number) if number>1 else '')
        stage_rows=[r for r in read_json(CFG/f'c6_map_{number}.json') if r['nd']==1]
        field=next(o for o,p in objects(prefab) if '_cellWidth' in o and p['_name']==f'nodeField{number}')
        points=next(o for o,_ in objects(prefab) if '_pointList' in o and nodes[nodes[o['node']]['_parent']]['_name']==f'nodeField{number}')['_pointList'][0]
        for n,(_,x,y) in enumerate(points,1):
            spawns.append(dict(id=f'{area}.spawn.{n}',area=area,number=n,grid_x=math.floor(x/field['_cellWidth']+y/field['_cellHeight']),grid_y=math.floor(y/field['_cellHeight']-x/field['_cellWidth'])))
        for lv,r in enumerate(stage_rows,1):
            ident=f'{area}.{lv}';configs.append(r)
            levels.append(dict(id=ident,area=area,level=lv,dungeon=r['gq_id'],normal_seconds=r['f_pt'],leader_seconds=r['f_sl'],mutant_chance=r['f_by'],mutant_count=r['by_num'],leader_chance=r['sl_pro'],leader_count=r['sl_num'],normal_points=r['sxd_pt'],leader_points=r['sxd_sl'],gate_resource='region.gate_'+r['dt_pic']))
            for role,source in [('normal','gw_pt'),('leader','gw_sl')]:
                for token in r[source].split(';'):
                    if not token:continue
                    mid,count=map(int,token.split(':'));key=ident+'.'+identities[mid]
                    members.append(dict(id=key,stage=ident,monster=identities[mid],count=count,role=role))
    write_csv(ROOT/'data/source/town/town_region_levels.csv',levels)
    write_csv(ROOT/'data/source/town/town_region_members.csv',members)
    write_csv(ROOT/'data/source/town/town_monster_spawns.csv',spawns)
    jobs=read_json(ROOT/'art_source/heroes/bake_jobs.json');known={r['name'] for r in jobs}
    rigs=read_json(SOURCE/'07_核验与索引/Spine索引.json')
    appearances=list(csv.DictReader((ROOT/'data/source/town/town_appearances.csv').open(encoding='utf-8')))
    for number,key in identities.items():
        model=models[source_monsters[number]['pic']]
        if key not in known:
            for direction in ['front','back']:
                entry=next(r for r in rigs if r['name']==f'tmp/role/monster/{model["name"]}/'+model['path_'+direction])
                job=copy_spine(entry,key,direction,'',[]);job['scale']=source_monsters[number]['sfbl']*0.5;jobs.append(job)
        scale=source_monsters[number]['sfbl']*0.5
        for job in jobs:
            if job['name']==key:job['scale']=scale
        appearances=[r for r in appearances if r['id']!=key]
        appearances.append(dict(id=key,scale=scale,name_x=model['name_point'][0],name_y=-model['name_point'][1]*scale,font_size=20,front_y=0,back_y=0))
    write_json(ROOT/'art_source/heroes/bake_jobs.json',jobs)
    write_csv(ROOT/'data/source/town/town_appearances.csv',appearances)
    schema_path=ROOT/'data/schema/data_schema.json';schema=read_json(schema_path)
    def f(n,t='string',**extra):return dict(name=n,type=t,required=True,**extra)
    def table(n,fields):schema['tables'][n]=dict(source=f'town/{n}.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','id')]+fields)
    fields=[f('id','id'),f('display_name'),f('visual','ref',table='town_appearances',field='id')]+[f(n,'float',min=0.01)for n in ['max_hp','attack','defense','attack_range','speed','respawn_seconds']]+[f('coins','int',min=0),f('city_speed','float',min=0.01),f('patrol_range','float',min=1),f('experience','int',min=0),f('source_id','int',min=1),f('area','ref',table='town_regions',field='id'),f('mutant','bool'),f('skill','int',min=1),f('appearance')]
    table('town_monsters',fields[1:])
    table('town_monster_spawns',[f('area','ref',table='town_regions',field='id')]+[f(n,'int',min=0)for n in ['number','grid_x','grid_y']])
    table('town_region_levels',[f('area','ref',table='town_regions',field='id')]+[f(n,'int',min=0)for n in ['level','dungeon','normal_seconds','leader_seconds','mutant_chance','mutant_count','leader_chance','leader_count']]+[f('normal_points'),f('leader_points'),f('gate_resource','ref',table='resource_bindings',field='id')])
    table('town_region_members',[f('stage','ref',table='town_region_levels',field='id'),f('monster','ref',table='town_monsters',field='id'),f('count','int',min=1),f('role','enum',values=['normal','leader'])])
    write_json(schema_path,schema)
    # Emit columns in schema order, matching the deterministic data pipeline.
    write_csv(ROOT/'data/source/town/town_monsters.csv',[{f['name']:r[f['name']] for f in fields} for r in monsters])
    dispatch=list(csv.DictReader((ROOT/'data/source/town/town_dispatch.csv').open(encoding='utf-8')))
    for r in dispatch:r['combat_enabled']=str(r['id']!='town').lower()
    write_csv(ROOT/'data/source/town/town_dispatch.csv',dispatch)
    sources=[prefab,CFG/'c2_guaiwu.json',CFG/'c59_guaiwu_model.json']+[CFG/f'c6_map_{i}.json' for i in range(1,4)]
    write_json(ROOT/'art_source/heroes/field_sources.json',dict(difficulty=1,stages=configs,spawns=spawns,sources=[dict(path=p.relative_to(SOURCE).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sources]))
    from import_region_ui_reference import main as ui
    ui()
    print(f'Regions: {len(levels)} levels, {len(monsters)} monster definitions, {len(spawns)} authored points')

if __name__=='__main__':main()
