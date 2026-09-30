"""Import private-bag/equipment UI art and current recipes' source affix rules."""
import csv
import hashlib
import shutil
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG


def main():
    lookup = {r['uuid']: r for r in read_json(SOURCE/'07_核验与索引/精灵切图索引.json')}
    names = {'empty':'9c6a48cf-a8d6-40ba-944d-b9c5bc77c608','panel':'b4705407-67be-4aee-9511-1e7b65f2ac24','line':'887937bf-e9e1-4993-8d97-cc2826bf53cc','buyback':'d21aea2d-4ef9-4bbb-9e35-e8601bc9bd5e','share':'0f1b7352-6acc-4dc8-9775-1ba4ec676b83','underline':'3997155e-9e85-4aff-9c86-30c6708e64f6','star':'ea0575fc-44b2-428c-9d00-4216fb434b80'}
    bindings, provenance = [], {}
    for name, key in names.items():
        row = lookup[key]; original = SOURCE/row['output']
        record = {'source':row['output'],'uuid':key,'sha256':hashlib.sha256(original.read_bytes()).hexdigest()}
        for directory in ['art_source/hero_inventory','assets/runtime/hero_inventory']:
            target=ROOT/directory/(name+'.png');target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(original,target)
            write_json(target.with_suffix('.png.json'),{'prompt':'Original source sprite; not AI generated.','source':record})
        provenance[name]=record
        bindings.append(dict(id='hero_inventory.'+name,asset_kind='texture_2d',source_path='art_source/hero_inventory/'+name+'.png',runtime_path='res://assets/runtime/hero_inventory/'+name+'.png',policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    prior=[r for r in csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8')) if not r['id'].startswith('hero_inventory.')]
    write_csv(ROOT/'data/source/resource_bindings.csv',prior+bindings)
    write_json(ROOT/'art_source/hero_inventory/provenance.json',provenance)
    equipment={r['id']:r for r in read_json(CFG/'c39_zhuangbei.json')}
    affixes={r['id']:r for r in read_json(CFG/'c39_citiao.json')}
    recovery=read_json(CFG/'z_1_1_zhuangbei_xidian.json')
    public=read_json(CFG.parent/'baseconf/c25_public.json')
    threshold=next(r for r in public if r['id']==1410)
    print('Source refine threshold:',threshold)
    rows=[]
    for recipe in csv.DictReader((ROOT/'data/source/town/town_equipment.csv').open(encoding='utf-8')):
        e=equipment[int(recipe['resource_id'].split('_')[-1])]
        assert e['ct_num']==1 and len(e['citiao1'][1])==1
        a=affixes[e['citiao1'][1][0]]
        price=next(r['recovery_price'] for r in recovery if r['difficulty']==e['nandu'] and r['quality']==e['pinzhi'])
        rows.append(dict(id=recipe['id'],source_id=e['id'],star=e['star_lv'],rank=e['nandu'],buyback=price,refine_quality=int(threshold['value']),affix_id=a['id'],effect=a['type'],label=a['remark'].replace('%s',''),minimum=a['sjlow1'],maximum=a['sjup1'],percent=a['type']!='dodge_up'))
    previous=list(csv.DictReader((ROOT/'data/source/town/main_equipment_rules.csv').open(encoding='utf-8')))
    equipment_ids={r['id'] for r in csv.DictReader((ROOT/'data/source/town/equipment_shop_equipment.csv').open(encoding='utf-8'))}
    write_csv(ROOT/'data/source/town/main_equipment_rules.csv',[r for r in rows if r['id'] not in equipment_ids]+[r for r in previous if r['id'] in equipment_ids])
    schema=read_json(ROOT/'data/schema/data_schema.json')
    schema['tables']['main_equipment_rules']={'source':'town/main_equipment_rules.csv','class':'definition','primary_key':['id'],'fields':[{'name':k,'type':'id' if k=='id' else 'bool' if isinstance(v,bool) else 'int' if isinstance(v,int) else 'string','required':True} for k,v in rows[0].items()]}
    write_json(ROOT/'data/schema/data_schema.json',schema)


if __name__=='__main__':main()
