"""Source battle horn definitions, exact UI sprites, and the six original boss rigs."""
import csv
import hashlib
import shutil
import sys
from import_town_reference import ROOT, read_json, write_json, write_csv
from import_hero_reference import SOURCE, CFG, copy_spine

ART = {
    'summon': '074ee034-010c-4d39-8cdc-1772bb2a33d1',
    'suspend': 'f6e5aa0d-d28d-42d5-98e1-b1c4f8f06d0d',
    'arrow': '4b9a01c0-97a4-4b3e-ac44-4ba1218e037d',
    'boss_ground': 'fb1cc0ad-9670-4afa-a101-10696124d560',
    'rewards': '01110ffe-dc70-4fb4-9966-ecff90446d45',
    'prop_bar': '63827b79-51e2-430f-abc7-840cd2d54245',
    'time': '3757521b-6375-4849-83c1-eb5049a03f5e',
    'ticket': 'tmp/prop/12001',
    'prepare': '953d42d3-7cdf-4d70-ace4-3d58cab3c445',
    'chest': 'tmp/treasure/baoxiang_04',
    'quality_6': 'tmp/quality/wuqipu_pingjie_dikuang006',
    'checkbox': 'tmp/login/jianli_gouxuan1',
    'checked': 'tmp/login/jianli_gouxuan2',
}


def rows(path):
    with path.open(encoding='utf-8') as stream:
        return list(csv.DictReader(stream))


def giant_impact():
    """Bake the source giant's two Cocos sprite tracks into the existing effect atlas."""
    from PIL import Image
    folder='03_美术资源/02_透明切图/resources/tmp/skillEffect/zijinguairen_atk/images/'
    upper=[dict(output=folder+f'zjgr_atk_shang_{i:02}.png') for i in range(18)]
    lower=dict(output=folder+'zjgr_atk_xia_00.png')
    # Authored child offsets: upper (-48.827,122.405), lower (0.519,-1.578).
    width,height=800,640
    sheet=Image.new('RGBA',(width*4,height*5))
    ground=Image.open(SOURCE/lower['output']).convert('RGBA')
    for i,r in enumerate(upper):
        frame=Image.new('RGBA',(width,height))
        t=i/30
        opacity=min(1,t*30) if t<.3 else max(0,(2/3-t)/(2/3-.3))
        shadow=ground.copy(); shadow.putalpha(shadow.getchannel('A').point(lambda a:round(a*opacity)))
        frame.alpha_composite(shadow,(round(width/2+.519-ground.width/2),round(height/2+1.578-ground.height/2)))
        image=Image.open(SOURCE/r['output']).convert('RGBA')
        frame.alpha_composite(image,(round(width/2-48.827-image.width/2),round(height/2-122.405-image.height/2)))
        sheet.paste(frame,((i%4)*width,(i//4)*height))
    return sheet,upper+[lower],18


def main():
    monsters = {r['id']: r for r in read_json(CFG/'c2_guaiwu.json')}
    upgrades = {r['id']: r for r in read_json(CFG/'c36_jz_zhaohuan.json')}
    definitions = read_json(CFG/'c43_boss_zhaohuan.json')
    drops = {r['id']: r for r in read_json(CFG/'c2_guaiwu_drop.json')}
    lang = {r['id']: r['text'] for r in read_json(CFG.parent/'langconf/c9_lang_chinese_simp.json')}
    levels = []
    skills = {r['id']:r for r in read_json(CFG/'skill_base.json')}
    for r in definitions:
        m, u = monsters[r['boss_id']], upgrades[r['id']]
        drop = drops[r['boss_id']]
        levels.append(dict(id='horn.'+str(r['id']), level=r['id'], monster_id=m['id'], display_name=lang[m['name_id']], visual=m['pic'],
            max_hp=m['hp'], attack=m['att'], defense=m['def'], speed=m['speed']*100, patrol_range=m['search_range'], attack_range=skills[m['skl_pg']]['sk1_range'], skill=m['skl_pg'],
            cost=int(u['xh'].split(':')[1]) if u['xh'] else 0, dungeon=u['dungeons'], prepare_seconds=r['pre_time'], fight_seconds=r['fight_time'],
            ticket_count=int(r['consume'].split(':')[1]), rewards=';'.join(f'{i}:{p}' for i,p in r['item']),
            drop_ground=drop['drop_ground'], drop_hero=drop['drop_hero'], coins=drop['jinbi'], chest=drop['bx'], experience=drop['exp']))
    schema = read_json(ROOT/'data/schema/data_schema.json')
    def f(n, t='string', **extra): return dict(name=n, type=t, required=True, **extra)
    schema['tables']['main_horn_levels'] = dict(source='town/main_horn_levels.csv', **{'class':'definition'}, primary_key=['id'], fields=[f('id','id'),f('level','int',min=1,max=30)] +
        [f(n,'int',min=0) for n in ['monster_id','skill','cost','dungeon','ticket_count','coins']] +
        [f(n,'float',min=.01) for n in ['max_hp','attack','defense','speed','patrol_range','attack_range','prepare_seconds','fight_seconds']] +
        [f(n) for n in ['display_name','visual','rewards','drop_ground','drop_hero','chest']]+[f('experience','int',min=0)])
    write_csv(ROOT/'data/source/town/main_horn_levels.csv', [{f['name']:r[f['name']] for f in schema['tables']['main_horn_levels']['fields']} for r in levels])
    for field in schema['tables']['main_horn_levels']['fields']:
        if field['name']=='visual': field.update(type='ref',table='town_appearances',field='id')
    chests=[dict(id='horn_chest.'+str(r['id']),rewards=r['general_awards']) for r in read_json(CFG/'c2_guaiwu_bx.json') if str(r['id']) in {i for l in levels for i in l['chest'].split(';')}]
    write_csv(ROOT/'data/source/town/main_horn_chests.csv',chests)
    schema['tables']['main_horn_chests']=dict(source='town/main_horn_chests.csv', **{'class':'definition'}, primary_key=['id'],fields=[f('id','id'),f('rewards')])
    write_json(ROOT/'data/schema/data_schema.json', schema)
    if '--data-only' in sys.argv: return
    frames = {k:r for r in read_json(SOURCE/'07_核验与索引/精灵切图索引.json') if r['bundle']=='resources' for k in [r['name'],r['uuid']]}
    item_defs={r['id']:r for r in read_json(CFG/'c22_item.json')}
    item_defs[101]=dict(pic='item_money_00.png',quality=4)
    reward_ids=sorted({int(p.split(':')[0]) for r in levels for p in r['rewards'].split(';')})
    rewards=[]
    for i in reward_ids:
        item=item_defs[i]
        ART['item_'+str(i)]='tmp/prop/'+item['pic'].removesuffix('.png')
        rewards.append(dict(id='horn_item.'+str(i),source_id=i,quality=item['quality'],resource_id='battle_horn.item_'+str(i)))
    write_csv(ROOT/'data/source/town/main_horn_items.csv',rewards)
    schema['tables']['main_horn_items']=dict(source='town/main_horn_items.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','id'),f('source_id','int',min=1),f('quality','int',min=1,max=6),f('resource_id','ref',table='resource_bindings',field='id')])
    write_json(ROOT/'data/schema/data_schema.json',schema)
    bindings = rows(ROOT/'data/source/resource_bindings.csv')
    bindings = [r for r in bindings if not r['id'].startswith('battle_horn.')]
    provenance = {}
    for name,key in ART.items():
        frame=frames[key]; source=SOURCE/frame['output']
        provenance[name]=dict(source=frame['output'],uuid=frame['uuid'],sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        for base in ['art_source','assets/runtime']:
            target=ROOT/base/'battle_horn'/f'{name}.png';target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,target)
            write_json(target.with_suffix('.png.json'),dict(prompt='Original source game sprite: '+frame['output']))
        bindings.append(dict(id='battle_horn.'+name,asset_kind='texture_2d',source_path=f'art_source/battle_horn/{name}.png',runtime_path=f'res://assets/runtime/battle_horn/{name}.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    write_csv(ROOT/'data/source/resource_bindings.csv',bindings)
    write_json(ROOT/'art_source/battle_horn/provenance.json',provenance)
    write_json(ROOT/'art_source/battle_horn/source_rules.json',dict(help=lang[41000014],levels=definitions,upgrades=list(upgrades.values()),paid=read_json(CFG/'c43_boss_shoufei.json'),cooldown=read_json(CFG/'c43_boss_cooldown.json')))
    if '--art-only' in sys.argv: return
    models={r['name']:r for r in read_json(CFG/'c59_guaiwu_model.json')}
    rigs=read_json(SOURCE/'07_核验与索引/Spine索引.json')
    wanted=sorted({r['visual'] for r in levels})
    jobs=[r for r in read_json(ROOT/'art_source/heroes/bake_jobs.json') if r['name'] not in wanted]
    appearances=[r for r in rows(ROOT/'data/source/town/town_appearances.csv') if r['id'] not in wanted]
    for name in wanted:
        model=models[name]
        for direction in ['front','back']:
            entry=next(r for r in rigs if r['name']==f'tmp/role/monster/{name}/'+model['path_'+direction])
            job=copy_spine(entry,name,direction,'',[]);job['scale']=model['bl'];jobs.append(job)
        appearances.append(dict(id=name,scale=model['bl'],name_x=model['name_point'][0]*model['bl'],name_y=-model['name_point'][1]*model['bl'],font_size=22,front_y=0,back_y=0))
    write_json(ROOT/'art_source/heroes/bake_jobs.json',jobs)
    write_csv(ROOT/'data/source/town/town_appearances.csv',appearances)
    print('Battle horn: 30 levels, 6 boss identities, 12 source rigs')


if __name__=='__main__': main()
