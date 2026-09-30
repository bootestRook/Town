"""Import recruitment source sprites and deterministic demo rule definitions."""
import csv, hashlib, shutil
from pathlib import Path
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG

def main():
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup = {key:r for r in frames if r['bundle']=='resources' for key in (r['uuid'],r['name'],r['frame_name'])}
    art = dict(background='zhaomu_diban1', captain='zhaomu_jianli_jindui_diban_npc',
        level='zhaomu_jianli_jindui_diban_lv', xp_frame='zhaomu_jianli_jindui_diban',
        xp_empty='zhaomu_jianli_jindui2', xp_fill='zhaomu_jianli_jindui1', info='zhaomu_jianli_jindui_diban_xiangqing',
        recruit='zhaomu_anniu1', finish='zhaomu_anniu2', refresh='zhaomu_anniu3',
        ticket='10001', cost='common_jiagetiao_da', timer='zhaomu_jianli_bj', help='comon_bangzhu',
        check='zhuye_jianzhu_wancheng', house='zm_weizhi', platform='xintaizi', beam='zm_daguang',
        glow='zm_beiguang', result='jiesuan_diban1', result_body='jiesuan_diban_1',
        rays='boss_jiesuan_shengli_guang', fragment='zhaomu_suipian', bar_empty='common_jindutiaio1', bar_fill='common_jindutiao3',
        purple='diban_anniu1', orange='diban_anniu2', video='common_guanggao',
        tab_dragon='zhuye_yeqian6', tab_dragon_selected='zhuye_yeqian6_xuanzhong',
        plus='common_shuliangweizhi1', minus='common_shuliangweizhi2', wish='yx_zhaomu', checkbox='common_weijiesuo', divider='common_zhuangshixian_02')
    art.update({f'job_{i}':f'tmp/heroOccupation/yx_zhiye{i}' for i in range(1,4)})
    for quality,name in [(4,'zi'),(5,'jin')]:
        art.update({f'column_{quality}_{i-1}':f'zmgz_{name}guangzhu{i:04d}' for i in range(1,16)})
    records,bindings={},[]
    for name,key in art.items():
        row=lookup[key]; original=SOURCE/row['output']
        record={'source':row['output'],'uuid':row['uuid'],'sha256':hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/recruitment','assets/runtime/recruitment']:
            p=ROOT/directory/(name+'.png');p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,p)
            write_json(p.with_suffix('.png.json'),{'prompt':'Original Mercenary Town sprite; not AI generated.','source':record})
        records[name]=record
        bindings.append(dict(id='recruitment.'+name,asset_kind='texture_2d',source_path='art_source/recruitment/'+name+'.png',runtime_path='res://assets/runtime/recruitment/'+name+'.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    spine=SOURCE/'03_美术资源/03_Spine骨骼/resources/__未命名/0c18c0dc-b455-4ea5-bcdb-fee1c9831f14'
    target=ROOT/'art_source/recruitment/spine';target.mkdir(exist_ok=True)
    for p in spine.iterdir():
        if p.suffix in ['.json','.atlas']:
            (target/p.name).write_text(p.read_text(encoding='utf-8-sig'),encoding='utf-8',newline='\n')
        else: shutil.copyfile(p,target/p.name)
        if p.suffix == '.png':
            write_json(target/(p.name+'.json'),{'prompt':'Original Mercenary Town Spine atlas; not AI generated.','source':str(p.relative_to(SOURCE)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    record={'prompt':'Original source Spine js_welcome_XH sampled with existing Pixi runtime; not AI generated.','source':str(spine.relative_to(SOURCE)),'frames':16,'columns':4,'width':620,'height':180,'hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in spine.iterdir()}}
    records['ribbon']=record
    for directory in ['art_source/recruitment','assets/runtime/recruitment']:write_json(ROOT/directory/'ribbon.png.json',record)
    bindings.append(dict(id='recruitment.ribbon',asset_kind='texture_2d',source_path='art_source/recruitment/ribbon.png',runtime_path='res://assets/runtime/recruitment/ribbon.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    for name,filename in [('reference','2cda5269-f7bd-4d16-9bbf-70537b52148e'),('confirm_reference','98c06659-ba9b-4139-9d65-5f210a66439e'),('refresh_reference','afed6fb5-1307-495b-a85c-7bda6cd7926d')]:
        original=Path('C:/Users/Arche/AppData/Local/Temp/codex-clipboard-'+filename+'.png')
        record={'prompt':'User supplied recruitment reference; original unchanged; AtlasTexture displays only requested UI regions.','source':original.name,'sha256':hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/recruitment','assets/runtime/recruitment']:
            target=ROOT/directory/(name+'.png');shutil.copyfile(original,target);write_json(target.with_suffix('.png.json'),record)
        records[name]=record
        bindings.append(dict(id='recruitment.'+name,asset_kind='texture_2d',source_path='art_source/recruitment/'+name+'.png',runtime_path='res://assets/runtime/recruitment/'+name+'.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    write_json(ROOT/'art_source/recruitment/provenance.json',records)
    old=list(csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf8')))
    write_csv(ROOT/'data/source/resource_bindings.csv',[r for r in old if not r['id'].startswith('recruitment.')]+bindings)
    schema=read_json(ROOT/'data/schema/data_schema.json')
    rows=list(csv.DictReader((ROOT/'data/source/town/main_recruit.csv').open(encoding='utf8')))
    sources={r['id']:r for r in read_json(CFG/'c29_zm_pond_pro.json')}
    for r in rows:
        src=sources[int(r['source_id'])]
        for q in range(2,6):
            r['draw_'+str(q)]=src[f'color{q}_pro']
            for p in range(1,4):r[f'pool_{q}_{p}']=src[f'color{q}_pond{p}']
    write_csv(ROOT/'data/source/town/main_recruit.csv',rows)
    fields=schema['tables']['main_recruit']['fields']
    for key in rows[0]:
        if key not in [f['name'] for f in fields]:fields.append({'name':key,'type':'int','required':True})
    public={r['id']:r for r in read_json(CFG.parent/'baseconf/c25_public.json')}
    rules=[dict(id=name,value=float(public[i]['value']),source_id=i) for name,i in [('duration',1175),('refresh_limit',1177),('ad_limit',1178),('ad_cooldown',1179),('refresh_price',1180),('experience',1194),('discount',1210)]]
    rules += [dict(id=k,value=v,source_id=0) for k,v in [('ticket',10001),('ticket_price',100),('wish_talent',1075004),('wish_multiplier',2),('wish_weight',100)]]
    write_csv(ROOT/'data/source/town/main_recruit_rules.csv',rules)
    heroes={int(r['source_id']):r['id'] for r in csv.DictReader((ROOT/'data/source/town/main_heroes.csv').open(encoding='utf8'))}
    pool=[dict(id='pool.'+str(r['id']),hero=heroes[r['hero']],quality=r['color'],pool=r['pond'],weight=r['pro']) for r in read_json(CFG/'c29_zm_pond.json') if r['hero'] in heroes]
    write_csv(ROOT/'data/source/town/main_recruit_pool.csv',pool)
    for name,fields in [('main_recruit_rules',[('id','id'),('value','float'),('source_id','int')]),('main_recruit_pool',[('id','id'),('hero','id'),('quality','int'),('pool','int'),('weight','int')])]:
        schema['tables'][name]={'source':'town/'+name+'.csv','class':'definition','primary_key':['id'],'fields':[{'name':k,'type':t,'required':True} for k,t in fields]}
    write_json(ROOT/'data/schema/data_schema.json',schema)
    print('Recruitment:',len(art),'source sprites,',len(pool),'pool entries')

if __name__=='__main__': main()
