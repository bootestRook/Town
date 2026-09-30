"""Import the configured map actors' original normal-attack timelines."""
import csv
import hashlib
import json
import shutil
import math
from PIL import Image
from PIL.PngImagePlugin import PngInfo
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG


def main():
    skills = {r['id']: r for r in read_json(CFG/'skill_base.json')}
    looks = {r['id']: r for r in read_json(CFG/'c25_zww.json')}
    models = read_json(CFG/'c59_guaiwu_model.json')
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    fx = {r['id']: r for r in read_json(CFG/'c52_skill_effect.json')}
    bullets = {r['id']: r for r in read_json(CFG/'c52_skill_bullets.json')}
    with (ROOT/'data/source/town/town_heroes.csv').open(encoding='utf-8') as stream:
        specs = [(r['visual'], {1:1000, 2:1001, 3:1002}[int(r['job'])], int(r['source_appearance'])) for r in csv.DictReader(stream)]
    with (ROOT/'data/source/town/town_monsters.csv').open(encoding='utf-8') as stream:
        specs += list({(r['visual'],int(r['skill']),r['appearance']) for r in csv.DictReader(stream) if r['mutant']=='false'})
    field_scales={r["id"]:float(r["scale"]) for r in csv.DictReader((ROOT/"data/source/town/town_appearances.csv").open(encoding="utf-8"))}
    specs.sort(key=lambda r:r[0])
    with (ROOT/'data/source/town/main_horn_levels.csv').open(encoding='utf-8') as stream:
        bosses = {r['visual']: int(r['skill']) for r in csv.DictReader(stream)}
    specs += [(visual, skill, visual) for visual, skill in bosses.items()]
    attacks, effects, sources = [], [], {}
    jobs = read_json(ROOT/'art_source/heroes/bake_jobs.json')
    equipment = read_json(CFG/'c39_zhuangbei.json')
    for actor, source_id, look_id in specs:
        s = skills[source_id]
        look = looks[look_id] if isinstance(look_id,int) else next(r for r in models if look_id in [r.get('id'),r.get('name'),r.get('appearance')])
        scale = .45 if isinstance(look_id,int) else field_scales[actor]
        emit, hit = look['lhp'+str(s['fs_coordinates'])], look['lhp2']
        attacks.append(dict(id=actor,source_id=source_id,variants=len(s['skl_bone_name']),windup=s['skl_dmg_time'][0]/1000,duration=s['skl_take_time']/1000,cooldown=s['cd_time']/1000,recovery=.1,fly_speed=s['fly_spd'],projectile='bullet.'+str(s['skl_res2'][0]) if s['skl_res2'] else '',impact='impact.'+str(s['skl_res4'][0]),emit_x=emit[0]*scale,emit_y=-emit[1]*scale,hit_x=hit[0]*scale,hit_y=-hit[1]*scale))
        for job in jobs:
            if job['name'] == actor:
                job['attacks'] = s['skl_bone_name']
                if isinstance(look_id,int):
                    arm=min([e for e in equipment if e['buwei']==1 and e['job']==look['job']],key=lambda e:(e['nandu'],e['pinzhi'],e['id']))
                    image=next(f for f in frames if f['name']=='tmp/equipSpine/'+arm['icon'])
                    target=ROOT/f'art_source/heroes/weapons/{arm["icon"]}.png'
                    target.parent.mkdir(parents=True,exist_ok=True)
                    shutil.copyfile(SOURCE/image['output'],target)
                    job['weapon']=target.relative_to(ROOT).as_posix()
                    job['weapon_source']=image['output']
        sources[actor] = dict(skill=s,look=look,role_scale=scale)
    wanted = {r['projectile'] for r in attacks if r['projectile']} | {r['impact'] for r in attacks}
    for key in sorted(wanted):
        kind, number = key.split('.')
        source = bullets[int(number)] if kind=='bullet' else fx[int(number)]
        if source.get('res_type') == 1:
            from import_battle_horn_reference import giant_impact
            sheet, selected, count = giant_impact()
            columns = 4
        else:
            selected = [r for r in frames if r['name']=='tmp/'+source['path']] if kind=='bullet' else sorted([r for r in frames if r['frame_name'].startswith(source['list'])],key=lambda r:r['frame_name'])
            images = [Image.open(SOURCE/r['output']).convert('RGBA') for r in selected]
            w,h = images[0].size
            count = len(images)
            columns = min(count, 4096 // w)
            sheet = Image.new('RGBA',(w*columns,h*math.ceil(count/columns)))
            for i,im in enumerate(images):
                assert im.size == (w,h)
                sheet.paste(im,((i%columns)*w,(i//columns)*h))
        assert selected, key
        origin = dict(config=source,frames=[dict(path=r['output'],sha256=hashlib.sha256((SOURCE/r['output']).read_bytes()).hexdigest()) for r in selected])
        info=PngInfo(); info.add_text('impeccable:prompt',json.dumps(origin,ensure_ascii=True))
        target=ROOT/f'art_source/heroes/fx/{key}.png';target.parent.mkdir(parents=True,exist_ok=True)
        sheet.save(target,pnginfo=info)
        effects.append(dict(id=key,resource_id='heroes.fx_'+key,frames=count,seconds=count*source.get('interval_time',50)/1000,scale=source['resizing'],rotation=source.get('orientations',0) if kind=='bullet' else 0,columns=columns,rows=math.ceil(count/columns),anchor=source.get('point1',2)))
        sources[key]=origin
    write_csv(ROOT/'data/source/town/town_attacks.csv',attacks)
    write_csv(ROOT/'data/source/town/town_effects.csv',effects)
    write_json(ROOT/'art_source/heroes/combat_sources.json',sources)
    write_json(ROOT/'art_source/heroes/bake_jobs.json',jobs)
    schema()


def schema():
    d=read_json(ROOT/'data/schema/data_schema.json')
    def f(name,kind='string',**opts):return dict(name=name,type=kind,required=True,**opts)
    d['tables']['town_attacks']=dict(source='town/town_attacks.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','id'),f('source_id','int',min=1),f('variants','int',min=1,max=3)]+[f(n,'float',min=0)for n in ['windup','duration','cooldown','recovery','fly_speed']]+[dict(name='projectile',type='ref',table='town_effects',field='id',required=False),f('impact','ref',table='town_effects',field='id')]+[f(n,'float')for n in ['emit_x','emit_y','hit_x','hit_y']])
    d['tables']['town_effects']=dict(source='town/town_effects.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','id'),f('resource_id','ref',table='resource_bindings',field='id'),f('frames','int',min=1),f('seconds','float',min=.01),f('scale','float',min=.01),f('rotation','float')]+[f(n,'int',min=1) for n in ['columns','rows','anchor']])
    animation=d['tables']['town_animations']['fields']
    next(f for f in animation if f['name']=='action')['values']=['idle','move','attack','death']
    animation[:]=[x for x in animation if x['name'] not in ['variant','source_animation']]+[f('variant','int',min=1,max=3),f('source_animation')]
    write_json(ROOT/'data/schema/data_schema.json',d)


if __name__=='__main__':main()
