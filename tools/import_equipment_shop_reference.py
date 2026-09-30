"""Import source weapon/armor definitions and their shared shop presentation."""
import csv
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_json, write_csv
from import_hero_reference import SOURCE, CFG

ART = {
    'arrival':'tmp/heroState/js_qipao_01',
    'walking':'tmp/heroState/js_zhuangtai_10',
    'armor_arrival':'tmp/heroState/js_qipao_02',
    'part_2_off':'2effe91a-a9b0-43b3-ab54-d7a8c67ca7ca',
    'part_2_on':'025f370f-94b7-483f-980c-20f16727986a',
    'part_4_off':'00d5aaf3-816f-4841-9ba0-66c44f19dcff',
    'part_4_on':'e617a7ac-55bb-44e5-bdd9-13edaeb8bf45',
    'rating_1':'tmp/eqicon/pinjia/zhuangbei_pinjia1',
    'rating_3':'tmp/eqicon/pinjia/zhuangbei_pinjia3',
    'job_1':'tmp/heroOccupation/yx_zhiye1',
    'job_2':'tmp/heroOccupation/yx_zhiye2',
    'job_3':'tmp/heroOccupation/yx_zhiye3',
    'slider_handle':'c4b82e10-bfe6-46c1-9f0d-e864fb747398',
    'slider_track':'a7d32349-e444-474c-a12b-8970649092d1',
    'cell':'474b663d-9160-4917-bda6-8018034c5ac7',
    'capacity':'d66edbe8-ea07-49cc-a5ef-513971efa559',
    'resolve':'1fd0c091-1380-43e6-8950-cbe74bb50de8',
    'hero_row':'c2ae473d-2e2b-4df4-ab78-1a6369b40579',
    'current':'6f38b73c-2e24-45d1-8b7c-290b1b9d4a58',
    'trade_header':'2856a4e9-367b-4544-9781-186a459adb61',
    'trade_background':'bffea62c-4b56-4ede-930c-159d6710d133',
    'equipment_panel':'54293df6-7b37-4289-ab4d-c3ac4f9daf71',
    'hero_gold':'4ccd3d09-f957-44e2-a10e-a48f0b8dc35c',
    'trade':'08156004-72e1-4d13-a420-309fd0fbdb94',
    'offer':'5aaee1a6-4b30-4a77-a181-c0457b4cdb89',
    'up':'d81678d2-2bec-412f-8dc7-83a71288ad6e',
    'craft_panel':'d235096f-89d2-49b8-acae-88a65dfc392d',
    'craft_button':'fed897cd-f222-46cb-b48d-4fc9113aeb9d',
    'tab0_on':'5f6e70af-d36e-4997-bf8c-8ec631a6011f',
    'tab0_off':'90a0021f-da78-4f5e-90e8-0b504188357f',
    'tab1_on':'2ed04753-5a4b-4bbb-ba8f-b34e8f490937',
    'tab1_off':'a2f58a7f-56af-4fb3-a093-74e841f53e64',
    'tab2_on':'a979de8f-1e7c-4128-bace-3390ce4d05f5',
    'tab2_off':'28dd240a-5ac5-45ae-8f9c-a133ec67227b',
    'tab3_on':'d7986fbf-2f07-47a0-87f7-a3b022f4dd50',
    'tab3_off':'779f9ae6-d7d4-46fb-b558-151e6645d78c',
}

def main():
    frames=read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    lookup={k:r for r in frames if r['bundle']=='resources' for k in [r['name'],r['uuid']]}
    bindings=[]; provenance={}
    def asset(name,key):
        if name in provenance:return 'equipment_shop.'+name
        r=lookup[key]; original=SOURCE/r['output']
        record={'source':r['output'],'uuid':r['uuid'],'sha256':hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/equipment_shop','assets/runtime/equipment_shop']:
            dest=ROOT/directory/(name+'.png');dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(original,dest)
            write_json(dest.with_suffix('.png.json'),{'prompt':'Exact original source sprite; not AI generated.','source':record})
        provenance[name]=record
        bindings.append(dict(id='equipment_shop.'+name,asset_kind='texture_2d',source_path='art_source/equipment_shop/'+name+'.png',runtime_path='res://assets/runtime/equipment_shop/'+name+'.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
        return 'equipment_shop.'+name
    for name,key in ART.items():asset(name,key)
    for i in range(1,6):asset('tier_'+str(i),'tmp/roundIcon/wuqipu_pingjie'+str(i))
    lang={r['id']:r['text'] for r in read_json(CFG.parent/'langconf/c9_lang_chinese_simp.json')}
    stores=[('building.6','c40_wuqidian','1','arrival'),('building.9','c40_fangjudian','2;4','armor_arrival')]
    shops=[]; levels=[]; unlock={}; owners={}
    for building,table,slots,bubble in stores:
        upgrade=read_json(CFG/(table+'.json'))
        shops.append(dict(id=building,display_name=lang[upgrade[0]['name']],description=lang[upgrade[0]['info']],slots=slots,arrival_resource='equipment_shop.'+bubble))
        for slot in slots.split(';'):owners[int(slot)]=building
        for r in upgrade:
            levels.append(dict(id=building+'.'+str(r['id']),building=building,level=r['id'],tier=r['nandu'],cost=int(r['xh'].split(':')[1]) if r['xh'] else 0,city=int(r['tj'].strip(';').split(':')[1]) if ':' in r['tj'] else 0,capacity=300))
            for token in r['js'].split(';'):
                if token:unlock[int(token)]=r['id']
    permanent=[r for r in read_json(CFG/'c51_tuzhi.json') if r['buwei'] in owners]
    drawings=[r for r in read_json(CFG/'c51_tuzhi_yicixing.json') if r['buwei'] in owners]
    canonical={r['zb_1']:'forge.'+str(r['id']) for r in permanent}
    equipment={r['id']:r for r in read_json(CFG/'c39_zhuangbei.json') if r['buwei'] in owners}
    affixes=read_json(CFG/'c39_citiao.json')
    attributes={r['id']:r for r in read_json(CFG/'c39_shuxing.json')}
    recovery=read_json(CFG/'z_1_1_zhuangbei_xidian.json')
    rows=[]; options=[]; rules=[]
    old_rules=list(csv.DictReader((ROOT/'data/source/town/main_equipment_rules.csv').open(encoding='utf-8')))
    sample=old_rules[0]
    for eq in equipment.values():
        eid=canonical.get(eq['id'],'equipment.'+str(eq['id']))
        rows.append(dict(id=eid,source_id=eq['id'],building=owners[eq['buwei']],display_name=lang[eq['name']],resource_id=asset('equip_'+str(eq['id']),'tmp/eqicon/'+eq['icon']),price=eq['basic_g'],job=eq['job'],slot=eq['buwei'],attribute=eq['sx'][0][0],attribute_name=lang[attributes[eq['sx'][0][0]]['name']],power=eq['sx'][0][1],quality=eq['pinzhi'],rank=eq['nandu'],star=eq['star_lv'],resolve=eq['fj_id']))
        for slot in range(1,eq['ct_num']+1):
            spec=eq['citiao'+str(slot)]
            for kind,ident,band in zip(*spec):
                pool=[a for a in affixes if (a['id']==ident if kind==1 else a['team_id']==ident)]
                for a in pool:
                    options.append(dict(id=f'{eid}.{slot}.{a["id"]}',equipment=eid,slot=slot,source_id=a['id'],effect=a['type'],label=lang[a['name']],minimum=a['sjlow'+str(band)],maximum=a['sjup'+str(band)],weight=a['proportion'] if kind==2 else 1,percent=attributes[a['sx_id']]['geshi']==3))
        first=next(x for x in options if x['equipment']==eid)
        price=next(r['recovery_price'] for r in recovery if r['difficulty']==eq['nandu'] and r['quality']==eq['pinzhi'])
        rules.append(dict(id=eid,source_id=eq['id'],star=eq['star_lv'],rank=eq['nandu'],buyback=price,refine_quality=int(sample['refine_quality']),affix_id=first['source_id'],effect=first['effect'],label=first['label'],minimum=first['minimum'],maximum=first['maximum'],percent=first['percent']))
    recipes=[]; item_ids=set()
    for once,source in [(False,permanent),(True,drawings)]:
        for r in source:
            for ident,_ in r['consume']:item_ids.add(ident)
            if once:item_ids.add(r['id'])
            eq=equipment[r['zb_1']]
            recipes.append(dict(id=('drawing.' if once else 'forge.')+str(r['id']),source_id=r['id'],building=owners[r['buwei']],slot=r['buwei'],display_name=lang[r['name']],resource_id=asset('recipe_'+str(r['id']),'tmp/prop/'+r['icon']),equipment=canonical.get(eq['id'],'equipment.'+str(eq['id'])),tier=r['nandu'],quality=r['pinzhi'],job=r['job'],unlock_level=0 if once else unlock[r['id']],one_use=once,cost=';'.join(f'{a}:{b}' for a,b in r['consume'])))
    items={r['id']:r for r in read_json(CFG/'c22_item.json')}
    item_rows=[]
    for ident in sorted(item_ids):
        r=items[ident]
        key='tmp/prop/'+str(ident)
        if key not in lookup:key='tmp/prop/'+next(x['icon'] for x in drawings if x['id']==ident)
        item_rows.append(dict(id='equipment_item.'+str(ident),source_id=ident,display_name=lang[r['name']],resource_id=asset('item_'+str(ident),key),quality=r['quality'],description=lang[r['info']]))
    schema=read_json(ROOT/'data/schema/data_schema.json')
    for name,values in [('equipment_shops',shops),('equipment_shop_levels',levels),('equipment_shop_recipes',recipes),('equipment_shop_equipment',rows),('equipment_shop_affixes',options),('equipment_shop_items',item_rows)]:
        write_csv(ROOT/f'data/source/town/{name}.csv',values)
        fields=[]
        for k,v in values[0].items():
            field=dict(name=k,type='id' if k=='id' else 'bool' if isinstance(v,bool) else 'int' if isinstance(v,int) else 'string',required=True)
            if k in ['resource_id','arrival_resource']:field.update(type='ref',table='resource_bindings',field='id')
            if k=='equipment':field.update(type='ref',table='equipment_shop_equipment',field='id')
            if k=='building':field.update(type='ref',table='equipment_shops',field='id')
            if k in ['cost','capacity','level','minimum','maximum','unlock_level','tier','power','price','weight'] and isinstance(v,int):field['min']=0
            fields.append(field)
        schema['tables'][name]=dict(source=f'town/{name}.csv',**{'class':'definition'},primary_key=['id'],fields=fields)
    write_json(ROOT/'data/schema/data_schema.json',schema)
    new_ids={r['id'] for r in rules}
    write_csv(ROOT/'data/source/town/main_equipment_rules.csv',[r for r in old_rules if r['id'] not in new_ids]+rules)
    prior=list(csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8')))
    write_csv(ROOT/'data/source/resource_bindings.csv',[r for r in prior if not r['id'].startswith('equipment_shop.')]+bindings)
    write_json(ROOT/'art_source/equipment_shop/provenance.json',provenance)
    print(f'Equipment shops: {len(levels)} levels, {len(permanent)} recipes, {len(drawings)} drawings, {len(rows)} equipment, {len(bindings)} exact sprites')

if __name__=='__main__':main()
