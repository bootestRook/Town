"""Source HeroListShowPnl art and full-body card poses; source tree stays read-only."""
import csv
import hashlib
import shutil
import subprocess
from import_town_reference import ROOT, read_json, write_csv, write_json
from import_hero_reference import SOURCE, CFG, RIGS


def main():
    frames = read_json(SOURCE/'07_核验与索引/精灵切图索引.json')
    by_name = {r['frame_name']: r for r in frames}
    by_path = {r['name']: r for r in frames}
    sources, bindings = {}, []

    def register(name, original, record):
        for directory in ['art_source/hero_roster', 'assets/runtime/hero_roster']:
            target = ROOT/directory/(name+'.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            if target != original: shutil.copyfile(original, target)
            write_json(target.with_suffix('.png.json'), {'prompt': 'Original Mercenary Town artwork or source Spine idle pose; not AI generated.', 'source': record})
        sources[name] = dict(record, sha256=hashlib.sha256(original.read_bytes()).hexdigest())
        bindings.append(dict(id='hero_roster.'+name, asset_kind='texture_2d', source_path='art_source/hero_roster/'+name+'.png', runtime_path='res://assets/runtime/hero_roster/'+name+'.png', policy_id='town_texture', budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))

    names = {'header':'common_dibu_tanchu', 'body':'common_dibu_tanchu1', 'close':'common_guanbi_xiao',
             'pill':'common_dibuhuchu_yeqian1', 'lineup':'yx_zhaomu', 'dispatch':'yx_zhandoushezhi',
             'locate':'yx_xinxikuang_didian', 'power_plate':'yx_kuang_anniu2', 'power_icon':'yingxiong_wuli',
             'rank':'tmp/roundIcon/wuqipu_pingjie1'}
    for quality in range(1, 6): names['quality_'+str(quality)] = 'tmp/heroQuality/third/yx_kuang_0'+str(quality)
    for job in range(1, 4): names['job_'+str(job)] = 'tmp/heroOccupation/zhiye0'+str(job)
    for element in range(1, 5): names['element_'+str(element)] = 'tmp/heroCamp/yx_zhenying'+str(element)
    stars = read_json(CFG/'c29_tf_star.json')
    for r in stars: names['star_'+str(r['id'])] = 'tmp/common/'+r['pic']
    for name, key in names.items():
        row = by_path[key] if key in by_path else by_name[key]
        register(name, SOURCE/row['output'], {'source':row['output'], 'uuid':row['uuid']})
    jobs = []
    current = read_json(ROOT/'art_source/heroes/bake_jobs.json')
    looks = {r['id']:r for r in read_json(CFG/'c25_zww.json')}
    for row in csv.DictReader((ROOT/'data/source/town/main_heroes.csv').open(encoding='utf-8')):
        look = looks[int(row['appearance'])]
        table = RIGS[int(row['job']),look['sex']][3]
        template = next(j for j in current if j['direction']=='front' and table in j['skeleton'])
        config = {r['id']:r for r in read_json(CFG/(table+'.json'))}
        hidden = []
        for part, choice in [(5,look['head']),(6,look['face']),(7,look['face'])]:
            for n in range(config[part]['num']):
                if n != choice or part == 7: hidden += config[part].get('slot_'+str(n),'').split(';')
        jobs.append(dict(template, name='hero_'+str(look['id']), appearance=look['id'], skin=config[4]['slot_'+str(look['body'])], hidden=[s for s in hidden if s], parts={p:look[p] for p in ['head','face','body']}))
    write_json(ROOT/'art_source/hero_roster/poses.json', jobs)
    subprocess.run(['node',str(ROOT/'tools/bake_hero_roster.cjs')],check=True,cwd=ROOT)
    for job in jobs:
        register(job['name'],ROOT/'art_source/hero_roster'/(job['name']+'.png'),{'skeleton':job['source'],'parts':job['parts'],'skin':job['skin'],'weapon':job['weapon_source'],'animation':'complete idl loop at 30Hz; fixed union framing'})
    write_json(ROOT/'art_source/hero_roster/provenance.json',sources)
    previous = [r for r in csv.DictReader((ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8')) if not r['id'].startswith('hero_roster.')]
    write_csv(ROOT/'data/source/resource_bindings.csv',previous+bindings)
    schema = read_json(ROOT/'data/schema/data_schema.json')
    write_csv(ROOT/'data/source/town/main_hero_idle.csv',read_json(ROOT/'art_source/hero_roster/idle.json'))
    schema['tables']['main_hero_idle']={'source':'town/main_hero_idle.csv','class':'definition','primary_key':['id'],'fields':[{'name':name,'type':kind,'required':True} for name,kind in [('id','id'),('appearance','int'),('frames','int'),('columns','int'),('duration','float')]]+[{'name':'resource_id','type':'ref','table':'resource_bindings','field':'id','required':True}]}
    rows=[dict(id='star.'+str(r['id']),stage=r['id'],count=r['num'],resource_id='hero_roster.star_'+str(r['id'])) for r in stars]
    write_csv(ROOT/'data/source/town/main_star_display.csv',rows)
    schema['tables']['main_star_display']={'source':'town/main_star_display.csv','class':'definition','primary_key':['id'],'fields':[{'name':'id','type':'id','required':True},{'name':'stage','type':'int','required':True},{'name':'count','type':'int','required':True},{'name':'resource_id','type':'ref','table':'resource_bindings','field':'id','required':True}]}
    fields=schema['tables']['main_hero_idle']['fields']
    schema['tables']['main_hero_idle']['fields']=fields[:2]+[fields[-1]]+fields[2:-1]
    write_json(ROOT/'data/schema/data_schema.json',schema)
    print('Imported hero roster art:',len(bindings),'including full-body heroes:',len(jobs))


if __name__ == '__main__': main()
