"""Extract native grid geometry, occupancy and actor presentation from local sources."""
import csv
from import_town_reference import ROOT, BUILD_PREFABS, read_json, write_json, write_csv
from import_hero_reference import SOURCE, CFG


def objects(path):
    data = read_json(path)
    def walk(value, parent=None):
        if not isinstance(value, list):
            return
        obj = {}
        if value and type(value[0]) is int and 0 <= value[0] < len(data[4]):
            mask = data[4][value[0]]
            obj = dict(zip([data[3][mask[0]][1][i] for i in mask[1:-1]], value[1:]))
            yield obj, parent
        for child in value:
            yield from walk(child, obj if isinstance(obj.get('_name'), str) else parent)
    return list(walk(data[5]))


def main():
    prefabs = SOURCE/'03_美术资源/04_预制体/resources/view'
    regions, cells, links = [], [], []
    for obj, parent in objects(prefabs/'map/Map.json'):
        if '_excludeCellDataBuffer' not in obj or parent['_name'] not in ['nodeCity','nodeField1','nodeField2','nodeField3']:
            continue
        zone = {'nodeCity':'town','nodeField1':'field','nodeField2':'field2','nodeField3':'field3'}[parent['_name']]
        origin = parent['_trs']
        center = obj['_centerGridPos'][1:]
        regions.append(dict(id=zone,origin_x=origin[0]+360,origin_y=4214-origin[1],tile_width=obj['_cellWidth'],tile_height=obj['_cellHeight'],count_x=obj['_cellXCount'],count_y=obj['_cellYCount'],center_x=center[0],center_y=center[1]))
        excluded = set(zip(map(ord,obj['_excludeCellDataBuffer'][::2]),map(ord,obj['_excludeCellDataBuffer'][1::2])))
        for x in range(obj['_cellXCount']):
            for y in range(obj['_cellYCount']):
                if (x,y) not in excluded:
                    cells.append(dict(id=f'{zone}.{x}.{y}',x=x,y=y,zone=zone))
        if zone=='town':
            for number,area in [(1,'field'),(2,'field2'),(3,'field3')]:
                links += [dict(id=f'exit.{number}.{i}',x=p[1],y=p[2],area=area) for i,p in enumerate(obj[f'_field{number}_EntryPointList'][0])]
    blocked=set()
    def block(x,y,w,h):
        blocked.update((x+dx,y+dy) for dx in range(w) for dy in range(h))
    doors={}
    for row in read_json(CFG/'c33_jianzhu.json'):
        # Cocos omits the BuildingEditorComponent default (0, 0).
        door=next((o['_buildDoorTilePos'][1:] for o,_ in objects(prefabs/f'build/Building{BUILD_PREFABS[row["id"]]}Prefab.json') if '_buildDoorTilePos' in o),[0,0])
        doors[f'building.{row["id"]}']=(row['x']-1+door[0],row['y']-1+door[1])
        block(row['x'],row['y'],row['grid_width'],row['grid_height'])
    heights={}
    for table,seat,key in [('c33_jianzhu_zaw','c33_zaw_seat','zaw_id'),('c33_jianzhu_zs','c33_zsw_seat','zsw_id')]:
        definitions={r['id']:r for r in read_json(CFG/(table+'.json'))}
        for place in read_json(CFG/(seat+'.json')):
            row=definitions[place[key]]
            prefix='barrier' if key=='zaw_id' else 'ornament'
            heights[f'{prefix}.{place["id"]}']=row['grid_height']
            if row['up_build']!=1:
                block(place['X'],place['Y'],row['grid_width'],row['grid_height'])
    cells=[r for r in cells if r['zone']!='town' or (r['x'],r['y']) not in blocked]
    write_csv(ROOT/'data/source/town/town_navigation.csv',cells)
    write_csv(ROOT/'data/source/town/town_regions.csv',regions)
    write_csv(ROOT/'data/source/town/town_exits.csv',links)
    path=ROOT/'data/source/town/town_buildings.csv'
    with path.open(encoding='utf-8') as f: buildings=list(csv.DictReader(f))
    for row in buildings: row['door_x'],row['door_y']=doors[row['id']]
    write_csv(path,buildings)
    path=ROOT/'data/source/town/town_scenery.csv'
    with path.open(encoding='utf-8') as f: scenery=list(csv.DictReader(f))
    for row in scenery: row['height']=heights[row['id']]
    write_csv(path,scenery)
    public={r['id']:r for r in read_json(CFG.parent/'baseconf/c25_public.json')}
    appearances=[]
    seen_monsters=set()
    for table in ['town_heroes','town_monsters']:
        path=ROOT/f'data/source/town/{table}.csv'
        with path.open(encoding='utf-8') as f: rows=list(csv.DictReader(f))
        for row in rows:
            if table=='town_heroes':
                base=read_json(CFG/('c10_hero_'+{1:'zs',2:'gs',3:'fs'}[int(row['job'])]+'.json'))[0]
                speeds=list(map(float,base['speed'].split('|')))
                value=sum(speeds)/len(speeds)
                skill_id={1:1000,2:1001,3:1002}[int(row['job'])]
                row['attack_range']=next(r['sk1_range'] for r in read_json(CFG/'skill_base.json') if r['id']==skill_id)
                appearances.append(dict(id=row['visual'],scale=.45,name_x=0,name_y=-114.096,font_size=18,front_y=1.763,back_y=-.926))
            else:
                if row['visual'] in seen_monsters:continue
                seen_monsters.add(row['visual'])
                model=next(r for r in read_json(CFG/'c59_guaiwu_model.json') if r['name']==row['appearance'])
                base=next(r for r in read_json(CFG/'c2_guaiwu.json') if r['pic']==model['name'])
                value=base['speed']
                scale=base['sfbl']*.5
                appearances.append(dict(id=row['visual'],scale=scale,name_x=model['name_point'][0],name_y=-model['name_point'][1]*scale,font_size=20,front_y=0,back_y=0))
            row['speed']=value*float(public[1042]['value'])
            row['city_speed']=value*float(public[1041]['value'])
        write_csv(path,rows)
    path=ROOT/'data/source/town/town_appearances.csv'
    known={r['id'] for r in appearances}
    appearances += [r for r in csv.DictReader(path.open(encoding='utf-8')) if r['id'] not in known]
    write_csv(path,appearances)
    jobs=read_json(ROOT/'art_source/heroes/bake_jobs.json')
    for job in jobs:
        if job['name'] in known:
            job['scale']=next(r['scale'] for r in appearances if r['id']==job['name'])
    write_json(ROOT/'art_source/heroes/bake_jobs.json',jobs)
    write_json(ROOT/'art_source/heroes/navigation_sources.json',dict(regions=regions,exits=links,doors=doors,blocked_city_cells=sorted(blocked),movement_multipliers={k:public[k] for k in [1041,1042]},appearances=appearances,hero_speed_initialization='Midpoint of source one-star profession speed interval; server instance unavailable'))
    schema()
    from import_field_reference import main as field_reference
    field_reference()
    for name in ['town_monsters','town_animations']:
        path=ROOT/f'data/source/town/{name}.csv'
        rows=list(csv.DictReader(path.open(encoding='utf-8')))
        fields=[f['name'] for f in read_json(ROOT/'data/schema/data_schema.json')['tables'][name]['fields']]
        write_csv(path,[{key:row[key] for key in fields} for row in rows])
    print('Native navigation:',len(cells),'cells;',len(blocked),'occupied city cells;',len(links),'source exits')


def schema():
    path=ROOT/'data/schema/data_schema.json'; d=read_json(path)
    def f(name,kind='float',**opts):return dict(name=name,type=kind,required=True,**opts)
    def table(name,fields): d['tables'][name]=dict(source=f'town/{name}.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','id')]+fields)
    table('town_regions',[f(n) for n in ['origin_x','origin_y']]+[f(n,'int',min=1) for n in ['tile_width','tile_height','count_x','count_y']]+[f(n,'int',min=0) for n in ['center_x','center_y']])
    table('town_navigation',[f('x','int',min=0),f('y','int',min=0),f('zone','ref',table='town_regions',field='id')])
    table('town_exits',[f('x','int',min=0),f('y','int',min=0),f('area','ref',table='town_regions',field='id')])
    table('town_appearances',[f('scale',min=.01),f('name_x'),f('name_y'),f('font_size','int',min=1),f('front_y'),f('back_y')])
    for name in ['town_heroes','town_monsters']:
        fields=d['tables'][name]['fields'];fields[:]=[r for r in fields if r['name']!='city_speed']+[f('city_speed',min=.01)]
    fields=d['tables']['town_buildings']['fields']; fields[:]=[r for r in fields if r['name'] not in ['door_x','door_y']]+[f('door_x','int',min=0),f('door_y','int',min=0)]
    fields=d['tables']['town_scenery']['fields']; fields[:]=[r for r in fields if r['name']!='height']+[f('height','int',min=1)]
    fields=d['tables']['town_animations']['fields']; fields[:]=[r for r in fields if r['name'] not in ['origin_y']]+[f('origin_y','int',min=0,max=4096)]
    write_json(path,d)


if __name__=='__main__':main()
