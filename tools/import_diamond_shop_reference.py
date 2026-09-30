"""Import original recharge art, reward reveal frames and sound; source stays read-only."""
import base64
import csv
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from import_main_ui_reference import ROOT, SOURCE, write_csv, write_json, read_json


def main():
    rows = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup = {key:r for r in rows if r['bundle']=='resources' for key in [r['uuid'],r['name'],r['frame_name']]}
    art = {'banner':'tmp/shop/bj', 'ribbon':'zuanshi_jiaobiao',
           'tab':'shangcheng_zuanshi_xuanzhong', 'top':'common_dinbu_bj',
           'diamonds':'common_dinbu_bj_zuanshi', 'coins':'common_dinbu_bj_jinbi', 'help':'common_bangzhu'}
    for i in range(1,7):
        art['gem_'+str(i)] = 'tmp/shop/zuanshi_'+str(i)
        art['card_'+str(i)] = 'shangcheng_kuang'+str(i+1)
    art.update({f'burst_{i}':f'click_efc1_{i:05d}' for i in range(16)})
    records, bindings = {}, []

    def copy(name, original, suffix='.png', kind='texture_2d'):
        record = {'source':str(original.relative_to(SOURCE)), 'sha256':hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/diamond_shop','assets/runtime/diamond_shop']:
            p=ROOT/directory/(name+suffix);p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,p)
            if suffix=='.png':write_json(p.with_suffix('.png.json'),{'prompt':'Original Mercenary Town source asset; not AI generated.','source':record})
        records[name]=record
        bindings.append(dict(id='diamond_shop.'+name,asset_kind=kind,source_path='art_source/diamond_shop/'+name+suffix,runtime_path='res://assets/runtime/diamond_shop/'+name+suffix,policy_id='town_texture' if kind=='texture_2d' else 'town_audio',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))

    for name,key in art.items():copy(name,SOURCE/lookup[key]['output'])
    audio=read_json(SOURCE/'04_配置表/JSON原表/resources/common/baseconf/c5_base_audio.json')
    for i,name in [(45,'click'),(46,'small_click'),(49,'reward_sound')]:
        row=next(r for r in audio if r['id']==i)
        original=SOURCE/'05_音频/resources/sound'/(row['path']+'.mp3')
        source=ROOT/'art_source/diamond_shop'/(name+'.wav')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(original),str(source)],check=True)
        shutil.copyfile(source,ROOT/'assets/runtime/diamond_shop'/(name+'.wav'))
        records[name]={'source':str(original.relative_to(SOURCE)),'sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'source_id':i}
        bindings.append(dict(id='diamond_shop.'+name,asset_kind='audio',source_path='art_source/diamond_shop/'+name+'.wav',runtime_path='res://assets/runtime/diamond_shop/'+name+'.wav',policy_id='audio_stream',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    # The reward's 30 Hz keyframes are retained beside their imported frames as evidence.
    index=read_json(SOURCE/'07_核验与索引/结构资源索引.json')
    for name,uid in [('reward_reveal','2e5b3238-3859-4543-a1c8-4f03c2e48639'),('reward_title','d98f4740-6868-439e-9634-33685a44b0e7')]:
        row=next(r for r in index if r['uuid']==uid)
        write_json(ROOT/'art_source/diamond_shop'/f'{name}.json',read_json(SOURCE/row['output']))
    # Bake script samples the original Spine already imported for recruitment.
    for name,animation,frames,columns,width,height,duration in [('reward_enter','js_welcome',80,4,620,180,2.6667),('reward_loop','js_welcome_XH',64,4,620,180,10.6)]:
        record={'prompt':'Original source Spine sampled with existing Pixi runtime; not AI generated.','source':'art_source/recruitment/spine/jiesuanmianban.json','animation':animation,'frames':frames,'columns':columns,'width':width,'height':height,'duration':duration}
        for directory in ['art_source/diamond_shop','assets/runtime/diamond_shop']:write_json(ROOT/directory/(name+'.png.json'),record)
        bindings.append(dict(id='diamond_shop.'+name,asset_kind='texture_2d',source_path='art_source/diamond_shop/'+name+'.png',runtime_path='res://assets/runtime/diamond_shop/'+name+'.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    write_json(ROOT/'art_source/diamond_shop/provenance.json',records)
    old=list(csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf8')))
    write_csv(ROOT/'data/source/resource_bindings.csv',[r for r in old if not r['id'].startswith('diamond_shop.')]+bindings)
    products=list(csv.DictReader((ROOT/'data/source/town/main_shop.csv').open(encoding='utf8')))
    for p in products:
        p.update(first_bonus=p['diamonds'],resource_id='diamond_shop.gem_'+p['source_id'],background_id='diamond_shop.card_'+p['source_id'])
    write_csv(ROOT/'data/source/town/main_shop.csv',products)
    schema=read_json(ROOT/'data/schema/data_schema.json');fields=schema['tables']['main_shop']['fields']
    for key,kind in [('first_bonus','int'),('resource_id','id'),('background_id','id')]:
        if key not in [f['name'] for f in fields]:fields.append({'name':key,'type':kind,'required':True})
    write_json(ROOT/'data/schema/data_schema.json',schema)
    print('Recharge source sprites:',len(art))


if __name__=='__main__':main()
