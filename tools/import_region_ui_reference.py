"""Exact region gate and density modal sprites; no redrawing or source mutation."""
import csv,hashlib,shutil,base64
from import_town_reference import ROOT,read_json,write_json,write_csv
from import_hero_reference import SOURCE,CFG
from import_navigation_reference import objects


def main():
    index=read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup={k:r for r in index if r['bundle']=='resources' for k in [r['name'],r['uuid']]}
    bindings=[r for r in csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8')) if not r['id'].startswith('region.')];provenance={}
    def asset(name,key):
        if name in provenance:return 'region.'+name
        r=lookup[key];original=SOURCE/r['output']
        record=dict(source=r['output'],uuid=r['uuid'],sha256=hashlib.sha256(original.read_bytes()).hexdigest());provenance[name]=record
        for base in ['art_source','assets/runtime']:
            target=ROOT/base/'region'/f'{name}.png';target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,target)
            write_json(target.with_suffix('.png.json'),dict(prompt='Exact original game sprite, unchanged pixels.',source=record))
        bindings.append(dict(id='region.'+name,asset_kind='texture_2d',source_path=f'art_source/region/{name}.png',runtime_path=f'res://assets/runtime/region/{name}.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
        return 'region.'+name
    for part,names in [('MapSwitchPnl',{'bg':'modal','helpBtn_be':'help','goodsShelf':'shelf','shuliang_wupin_dikuang_wenben':'drop_title','jiesuan_fengexian':'divider'}),('MapSwitchItemCmpt',{'bg':'row','currDensity':'active','activate':'activate','activated':'activated','eliteIcon':'elite','shuliang_zhezhao':'count_bg'})]:
        p=SOURCE/f'03_美术资源/04_预制体/resources/view/mapSwitch/{part}.json';d=read_json(p)
        for o,parent in objects(p):
            if '_spriteFrame' not in o or parent['_name'] not in names:continue
            v=d[1][d[10][o['_spriteFrame']]];h=v[:2]+base64.b64decode(v[2:]+'==').hex();u='-'.join([h[:8],h[8:12],h[12:16],h[16:20],h[20:]])
            asset(names[parent['_name']],u)
    for r in read_json(CFG/'c2_guaiwu.json')[:9]:asset('monster_'+str(r['id']),'tmp/dfMonsters/'+r['pic'])
    p=SOURCE/'03_美术资源/04_预制体/resources/view/map/Map.json';obs=objects(p);regions=[]
    lang={r['id']:r['text'] for r in read_json(CFG.parent/'langconf/c9_lang_chinese_simp.json')}
    c8=read_json(CFG/'c8_map.json')[0]
    for i in range(1,4):
        area='field'+(str(i) if i>1 else '')
        gate=next(o for o,_ in obs if o.get('_name')==f'nodeSwitch{i}')
        click=next(o for o,parent in obs if o.get('_name')=='click' and parent.get('_name')==f'nodeSwitch{i}')
        regions.append(dict(id=area,display_name=lang[2012+i],gate_x=gate['_trs'][0]+360,gate_y=4214-gate['_trs'][1],click_x=click['_trs'][0],click_y=-click['_trs'][1],drops=c8[f'drop{i}'],help_text=lang[41000042+i*2]))
        for r in read_json(CFG/f'c6_map_{i}.json')[:3]:asset('gate_'+r['dt_pic'],'tmp/mapSwitch/switchLevel/'+r['dt_pic'])
    items={r['id']:r for r in read_json(CFG/'c22_item.json')}
    items.update({r['id']:r for r in read_json(CFG/'c21_resouce.json')})
    item_rows=[]
    for ident in sorted({int(x) for r in regions for x in r['drops'].split(',')}):
        r=items[ident];asset('drop_'+str(ident),'tmp/prop/'+r['pic'].removesuffix('.png'))
        item_rows.append(dict(id='item.'+str(ident),source_id=ident,display_name=lang[r['name']],quality=r['quality'],tier=r['grade'],description=lang[int(r['info'])],resource_id='region.drop_'+str(ident)))
    write_csv(ROOT/'data/source/town/town_region_items.csv',item_rows)
    write_csv(ROOT/'data/source/town/town_region_gates.csv',regions)
    schema=read_json(ROOT/'data/schema/data_schema.json')
    def f(n,t='string',**extra):return dict(name=n,type=t,required=True,**extra)
    schema['tables']['town_region_gates']=dict(source='town/town_region_gates.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','ref',table='town_regions',field='id'),f('display_name')]+[f(n,'float') for n in ['gate_x','gate_y','click_x','click_y']]+[f('drops'),f('help_text')])
    schema['tables']['town_region_items']=dict(source='town/town_region_items.csv',**{'class':'definition'},primary_key=['id'],fields=[f('id','id'),f('source_id','int',min=1),f('display_name'),f('quality','int',min=1),f('tier','int',min=0),f('description'),f('resource_id','ref',table='resource_bindings',field='id')])
    write_json(ROOT/'data/schema/data_schema.json',schema);write_csv(ROOT/'data/source/resource_bindings.csv',bindings)
    write_json(ROOT/'art_source/region/provenance.json',provenance)

if __name__=='__main__':main()
