"""Import the supplied main UI assets and client configuration, without changing the source."""
import csv
import hashlib
import shutil
import subprocess
from pathlib import Path
from import_main_collections import import_collections
from import_main_combat import import_combat, combat_fields
from import_town_reference import ROOT, read_json, write_csv, write_json

SOURCE = Path('F:/GameResearch/佣兵小镇')


def main():
    frames = read_json(SOURCE / '07_核验与索引/精灵切图索引.json')
    by_key = {key: row for row in frames if row['bundle'] == 'resources'
              for key in (row['name'], row['uuid'])}
    by_name = {row['frame_name']: row for row in frames if row['bundle'] == 'resources'}
    records, bindings = {}, []

    def asset(name, key):
        row = by_key.get(key) or by_name[key]
        source = SOURCE / row['output']
        for folder in ['art_source/main_ui', 'assets/runtime/main_ui']:
            target = ROOT / folder / (name + '.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        records[name] = {'source': row['output'], 'uuid': row['uuid'],
                         'sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
        if 'origin' in row:
            records[name]['spine_source'] = row['origin']
        for folder in ['art_source/main_ui', 'assets/runtime/main_ui']:
            write_json(ROOT / folder / (name + '.png.json'), {
                'prompt': 'Source reuse, not AI generated. Mercenary Town source UUID ' + row['uuid'] +
                          '; origin: ' + row.get('origin', row['output']) +
                          ('; Spine idle pose baked by tools/bake_main_portraits.cjs.' if 'origin' in row else '; original pixels and file bytes retained.'),
                'sha256': records[name]['sha256']})
        aid = 'main_ui.' + name
        bindings.append(dict(id=aid, asset_kind='texture_2d', source_path=f'art_source/main_ui/{name}.png',
                             runtime_path=f'res://assets/runtime/main_ui/{name}.png', policy_id='town_texture',
                             budget_group='town', owner='prototype_team', license_id='third_party', required='true', consumer='town'))
        return aid

    assets = dict(top='dingbu_xinxitiao1', avatar='tmp/profilephoto/1008', avatar_frame='touxiangkuang',
                  power_icon='common_dinbu_zhandouli', coins='common_dinbu_bj_jinbi', diamonds='common_dinbu_bj_zuanshi',
                  energy='common_dinbu_bj_jinhua', bottom='common_dibu_bj', red_dot='common_hongdian3',
                  dungeon_bg='820e5218-b6f7-4b44-9618-718ec0b83348', recruit_bg='0e029822-596f-45bc-bdb9-f8f0eb95d721',
                  recruit_button='4501f7b5-2e15-4bd3-8aae-0cebfb981262', refresh_button='c817fb96-bf6e-46d4-9004-aeb861158ac8',
                  shop_bg='26dea338-a91a-4ef0-9322-55ecd6d2cb74', hero_card='a217739a-1427-4122-90de-3725e77258e9',
                  gold_bg='91f72694-8be0-468b-9700-93fc6e73e4cd', energy_bg='15b8bf3e-d850-4bcb-8864-d70695081f11',
                  resource_body='aa98c73c-52b0-4c2e-a532-160dae8e4f2d', resource_title='5fee6611-64da-4491-86b8-46514b5a4723',
                  diamond_icon='tmp/prop/item_money_01', resource_card='bd91d01b-5ff5-4865-8a01-2786c7ca0744')
    for i, suffix in enumerate([6, 3, 2, 4, 1]):
        assets[f'nav_{i}'] = f'zhuye_yeqian{suffix}'
        assets[f'nav_{i}_selected'] = f'zhuye_yeqian{suffix}_xuanzhong'
    for name, key in assets.items():
        asset(name, key)
    cfg = SOURCE / '04_配置表/JSON原表/resources/common/json'
    lang = {r['id']: r['text'] for r in read_json(SOURCE / '04_配置表/JSON原表/resources/common/langconf/c9_lang_chinese_simp.json')}
    pictures = {r['pic'] for n in ['c45_dixiacheng_0','c92_jlmj_monster','c94_sjboss'] for r in read_json(cfg/(n+'.json'))}
    boss_ids = {r['boss_id'] for r in read_json(cfg/'c43_boss_zhaohuan.json')}
    pictures.update(r['pic'] for r in read_json(cfg/'c2_guaiwu.json') if r['id'] in boss_ids)
    spine = read_json(SOURCE/'07_核验与索引/Spine索引.json')
    jobs = []
    for picture in sorted(pictures):
        if 'tmp/dfMonsters/'+picture in by_key:
            continue
        entries = [r for r in spine if r['name'].startswith('tmp/role/monster/'+picture+'/')]
        entries = [r for r in entries if 'bei' not in r['name'].split('/')[-1] and not r['name'].split('/')[-1].startswith('b')]
        if not entries:
            raise ValueError('Missing source monster skeleton '+picture)
        entry = entries[0]
        source = SOURCE/entry['output']
        directory = ROOT/'art_source/main_ui/spine'/picture
        directory.mkdir(parents=True,exist_ok=True)
        for p in source.parent.iterdir():
            if p.suffix in ['.json','.skel','.atlas','.png']:
                if p.suffix in ['.json','.atlas']:
                    (directory/p.name).write_text(p.read_text(encoding='utf-8-sig'),encoding='utf8',newline='\n')
                else: shutil.copyfile(p,directory/p.name)
        output=ROOT/'art_source/main_ui/baked'/(picture+'.png')
        jobs.append(dict(name=picture,skeleton=(directory/source.name).relative_to(ROOT).as_posix(),output=output.relative_to(ROOT).as_posix(),source=entry['output']))
        by_key['spine:'+picture]={'output':str(output),'uuid':entry['uuid'],'origin':entry['output']}
    write_json(ROOT/'art_source/main_ui/portrait_jobs.json',jobs)
    if jobs:
        subprocess.run(['node',str(ROOT/'tools/bake_main_portraits.cjs')],cwd=ROOT,check=True)
    schema = read_json(ROOT / 'data/schema/data_schema.json')

    def table(name, rows):
        for row in rows:
            if str(row['id']).isdigit():
                row['source_id'] = int(row['id'])
                row['id'] = name.removeprefix('main_') + '.' + str(row['id'])
        write_csv(ROOT / f'data/source/town/{name}.csv', rows)
        fields = []
        for key, value in rows[0].items():
            kind = 'id' if key == 'id' else 'int' if isinstance(value, int) else 'float' if isinstance(value, float) else 'string'
            field = dict(name=key, type=kind, required=True)
            if key == 'resource_id':
                field.update(type='ref', table='resource_bindings', field='id')
            fields.append(field)
        schema['tables'][name] = dict(source=f'town/{name}.csv', **{'class': 'definition'}, primary_key=['id'], fields=fields)

    purchase = []
    for table_name, kind in [('gold_purchase', 'coins'), ('c89_jhzl', 'energy')]:
        for row in read_json(cfg / (table_name + '.json')):
            for i, pair in enumerate(row['purchase_consume']):
                purchase.append(dict(id=f'{kind}.{row["id"]}.{i}', kind=kind, city_level=row['id'], step=i,
                                     cost=pair[0], amount=pair[1], limit=row['pay_number'],
                                     free_amount=row.get('ad_gold', row.get('time_number',[[0,0]])[0][1]), free_limit=row.get('ad_number', 3),
                                     capacity=row.get('max', 0), initial=row.get('initial', 0)))
    table('main_purchase', purchase)
    table('main_recruit', [dict(id=str(r['id']), experience=r['exp'], green=r['color2'], blue=r['color3'], purple=r['color4'], gold=r['color5'], interval=r['interval'])
                           for r in read_json(cfg / 'c29_zm_pond_pro.json')])
    price2 = {r['id']: r for r in read_json(cfg / 'c29_zm_jg2.json')}
    table('main_recruit_prices', [dict(id=str(r['id']), first=price2[r['id']]['price1'], second=price2[r['id']]['price2'], third=r['price']) for r in read_json(cfg / 'c29_zm_jg3.json')])
    talents = {r['id']: r for r in read_json(cfg / 'c29_tf2.json')}
    appearances = {r['id']: r for r in read_json(cfg / 'c25_zww.json')}
    jobs = {i: read_json(cfg / f'c10_hero_{suffix}.json')[0] for i, suffix in [(1, 'zs'), (2, 'gs'), (3, 'fs')]}
    growth = {r['id']: r for r in read_json(cfg / 'c11_hero_growth.json')}
    pools = read_json(cfg / 'c29_zm_pond.json')
    heroes = []
    for appearance_id, appearance in appearances.items():
        candidates = [talents[r['hero']] for r in pools if r['hero'] in talents and talents[r['hero']]['zww'] == appearance_id]
        if not candidates:
            continue
        talent = min(candidates, key=lambda r: r['id'])
        pool = [r for r in pools if r['hero'] == talent['id']]
        if not pool:
            continue
        job = jobs[talent['job']]
        quality = talent['color']
        g = growth[min(quality, 5)]
        midpoint = lambda v: sum(float(x) for x in v.split('|')) / len(v.split('|'))
        name = lang[appearance['name']]
        heroes.append(dict(id=str(talent['id']), appearance=appearance_id, display_name=name, job=talent['job'], quality=quality,
                           max_level=talent['max_lv'], star=talent['star'], resource_id=asset('hero_' + str(appearance_id), 'tmp/profilephoto/' + appearance['pic']),
                           hp=midpoint(job['hp']), attack=midpoint(job['att']), defense=midpoint(job['def']),
                           hp_growth=midpoint(g['hp']), attack_growth=midpoint(g['att']), defense_growth=midpoint(g['def']),
                           weight=sum(r['pro'] for r in pool), fragment=str(talent['xh']), fragment_count=talent['xh_num'], skills=talent['skill']))
        heroes[-1].update(combat_fields(job, talent['yszy'], True))
    table('main_heroes', heroes)
    table('main_talents', [dict(id=str(r['id']), appearance=r['zww'], star=r['star'], max_level=r['max_lv'],
                               next_id=r['next_id'], fragment_count=r['xh_num'], hp=float(r['hp']), attack=float(r['att']), defense=float(r['def']),
                               skills='|'.join(r[k] for k in ['skill','skill1','skill2','skill3','skill4']))
                          for r in talents.values() if r['zww'] in {h['appearance'] for h in heroes}])
    item_rows = read_json(cfg/'c21_resouce.json') + read_json(cfg/'c22_item.json')
    table('main_items', [dict(id=str(r['id']), display_name=lang.get(int(r['name']),r.get('remark2','')) or str(r['id'])) for r in item_rows])
    table('main_rules', [dict(id=str(r['id']), value=int(r['value'])) for r in read_json(cfg.parent/'baseconf/c25_public.json') if r['id'] in [1228,1229,1230]])
    table('main_skills', [dict(id=str(r['id']), display_name=lang[r['skl_name']] if r['skl_name'] else r['function_name'], description=lang[r['descriptionid']] if r['descriptionid'] else r['function_name'],
                              cooldown=r['cd_time']/1000.0, damage_type=r['damage_type'], multiplier=';'.join(map(str,r['level_value'])), targets=r['hit_num'],
                              target=r['target'], buffs=';'.join(map(str,r['add_buff'])), percent_attribute=r['damage_arg1'], percent_target=r['damage_arg2'])
                         for r in read_json(cfg/'skill_base.json')])
    import_combat(cfg, lang, table)
    levels = []
    for r in read_json(cfg / 'c45_dixiacheng.json'):
        levels.append(dict(id=str(r['id']), chapter=r['zj'], floor=r['cj'], title=lang.get(r['name'], str(r['id'])),
                           chapter_name=lang.get(r['zj_name'], '地下城'), power=r['zl'], city_level=r['zc_lv'],
                           rewards=r['item'] or '-', enemies=';'.join(str(r['gw'+str(i)]) for i in range(1, 6)), cost=r['xh']))
    table('main_dungeons', levels)
    enemies = []
    enemy_assets = {}
    def enemy(row, prefix, portrait=None, title=None):
        key = portrait or ('tmp/dfMonsters/' + row['pic'])
        if key.startswith('tmp/dfMonsters/') and key not in by_key: key='spine:'+key.split('/')[-1]
        if key not in enemy_assets:
            enemy_assets[key] = asset('enemy_' + str(len(enemy_assets)), key)
        eid = prefix + '.' + str(row['id'])
        enemies.append(dict(id=eid, display_name=title or lang.get(row.get('name',0), '守卫'), resource_id=enemy_assets[key],
                            hp=float(row['hp']), attack=float(row['att']), defense=float(row['def']), frequency=float(row.get('freq',1))))
        enemies[-1].update(combat_fields(row))
        talent = talents.get(row.get('tf')) if prefix in ['cloud','arena'] else None
        if talent:
            enemies[-1]['skills'] = '|'.join(talent[k] for k in ['skill','skill1','skill2','skill3','skill4'])
            enemies[-1]['element'] = talent['yszy']
        else:
            normal = row.get('skl_pg', row.get('pg', 1000))
            active = [row.get('skill',0)] + [row.get('skill'+str(i),0) for i in range(1,5)]
            enemies[-1]['skills'] = '|'.join(str(k)+';1' for k in [normal]+active if k)
        enemies[-1]['role'] = 'hero' if prefix in ['cloud','arena'] else 'boss' if prefix in ['boss','dragon'] else 'monster'
        return eid
    for row in read_json(cfg/'c45_dixiacheng_0.json'): enemy(row, 'dungeon')
    for row in read_json(cfg/'c92_jlmj_monster.json'): enemy(row, 'fairy')
    encounters = []
    rewards = lambda pairs: ';'.join(f'{a}:{b}' for a,b in pairs) or '-'
    def encounter(eid, mode, index, title, foes, reward, cost=0, seconds=180):
        encounters.append(dict(id=eid, mode=mode, stage=index, title=title, enemies=';'.join(foes), rewards=reward,
                               cost=cost, seconds=seconds))
    for i,row in enumerate(read_json(cfg/'c45_dixiacheng.json')):
        encounter('dungeon.'+str(row['id']), 'dungeon', i, lang.get(row['name'],'地下城'),
                  ['dungeon.'+str(row['gw'+str(j)]) for j in range(1,6) if row['gw'+str(j)]], row['item'] or '-', row['xh'])
    for i,row in enumerate(read_json(cfg/'c92_jlmj.json')):
        encounter('fairy.'+str(row['id']), 'modes.2', i, '精灵秘境 第%d层'%(i+1),
                  ['fairy.'+str(eid) for eid,count in row['gw_pt']+row['gw_sl'] for _ in range(count)], rewards(row['drop_item']), row['energy'], row['battle_time'])
    def bot(row, prefix):
        appearance = appearances[talents[row['tf']]['zww']]
        return enemy(row, prefix, 'tmp/profilephoto/'+appearance['pic'], lang[appearance['name']])
    for row in read_json(cfg/'c93_yzcsl_jqrsx.json'): bot(row,'cloud')
    for i,row in enumerate(read_json(cfg/'c93_yzcsl.json')):
        encounter('cloud.'+str(row['id']),'modes.4',i,'云中城试炼 第%d层'%(i+1),
                  ['cloud.'+str(row['hero_'+str(j)][1]) for j in range(1,6) if row['hero_'+str(j)]], rewards(row['drop_item']))
    for row in read_json(cfg/'c72_pvp_jqrsx.json'): bot(row,'arena')
    for i,row in enumerate(reversed(read_json(cfg/'c72_pvp_jqr.json'))):
        encounter('arena.'+str(row['id']),'modes.1',i,'竞技场 对手%d'%(i+1),
                  ['arena.'+str(row['hero_'+str(j)]) for j in range(1,6) if row['hero_'+str(j)]], '103:10;14020:40')
    bosses = {r['id']:r for r in read_json(cfg/'c2_guaiwu.json')}
    boss_drops = {r['id']:r for r in read_json(cfg/'c2_guaiwu_drop.json')}
    for i,row in enumerate(read_json(cfg/'c43_boss_zhaohuan.json')):
        monster = bosses[row['boss_id']]
        eid = 'boss.'+str(monster['id'])
        if not any(e['id']==eid for e in enemies): enemy(dict(monster,name=monster['name_id']), 'boss')
        drop=boss_drops[row['boss_id']]
        guaranteed=[[101,drop['jinbi']]]
        for pair in (drop['drop_hero']+';'+drop['drop_ground']).split(';'):
            if not pair: continue
            item,chance,minimum,maximum=map(int,pair.split('|'))
            if chance==10000: guaranteed.append([item,minimum])
        encounter('boss.'+str(row['id']),'modes.6',i,lang[monster['name_id']], [eid], rewards(guaranteed), 0, row['fight_time'])
    dragons = {r['id']:r for r in read_json(cfg/'c94_sjboss.json')}
    dragon_stats = read_json(cfg/'c94_sjboss_sx.json')
    for i,row in enumerate(dragon_stats):
        dragon = dragons[row['appearance']]
        eid = enemy(row,'dragon','tmp/dfMonsters/'+dragon['pic'],lang[dragon['boss_name']])
        encounter('dragon.'+str(row['id']),'modes.3',i,lang[dragon['boss_name']], [eid], rewards(row['gift']), 10, 180)
    table('main_enemies', enemies)
    table('main_encounters', encounters)
    table('main_sea', [dict(id=str(r['id']), display_name=lang[r['name']], cost=r['strength'], seconds=r['time'],
                            resource_id=asset('sea_'+str(r['id']),r['pic'])) for r in read_json(cfg/'c99_hsyj_yj.json')])
    table('main_sea_rewards', [dict(id=str(r['id']), low=rewards(r['item_1']), middle=rewards(r['item_2']), high=rewards(r['item_3'])) for r in read_json(cfg/'c99_hsyj_jl.json')])
    table('main_city', [dict(id=str(r['id']), cost=int(r['xh'].split(':')[1]), dungeon=r['dungeons']) for r in read_json(cfg/'c46_zhucheng.json')])
    modes = []
    for r in sorted(read_json(cfg / 'c92_mj.json'), key=lambda v: v['order']):
        modes.append(dict(id=str(r['id']), display_name=lang[r['name']].replace('BOSS', '首领'), order=r['order'],
                          resource_id=asset('mode_'+str(r['id']), 'tmp/secretArea/mijing_neirong'+str(r['id'])), source_task=r['task_id']))
    table('main_modes', modes)
    table('main_shop', [dict(id=str(r['id']), display_name=r['des'], diamonds=int(r['itemnum'].split(':')[1]), price=int(r['cost']))
                        for r in read_json(cfg / 'c70_shop_1.json') if r['id'] < 100])
    import_collections(cfg, lang, table, asset)
    # Retain the original rows alongside the normalized CSV for audit, not runtime mutation.
    original_tables = ['c92_mj','c29_zm_pond','c29_zm_pond_pro','c29_tf2','skill_base','skill_passive','skill_buff',
                       'gold_purchase','c89_jhzl','c70_shop_1','c45_dixiacheng','c45_dixiacheng_0','c92_jlmj',
                       'c92_jlmj_monster','c93_yzcsl','c93_yzcsl_jqrsx','c72_pvp_jqr','c72_pvp_jqrsx',
                       'c43_boss_zhaohuan','c94_sjboss_sx','c99_hsyj_yj','c99_hsyj_jl','c46_zhucheng',
                       'c92_cw','c92_cw_lv','c92_cw_skill','c92_cw_skill_base','c102_shenqi',
                       'c102_shenqi_upgradation','c102_shenqi_pz','c21_resouce','c22_item',
                       'c70_product_list','c70_libao2','c70_thlb','c70_thlb_time']
    originals = {n: read_json(cfg/(n+'.json')) for n in original_tables}
    originals['c25_public'] = read_json(cfg.parent/'baseconf/c25_public.json')
    write_json(ROOT / 'art_source/main_ui/source_tables.json', originals)
    write_json(ROOT / 'data/schema/data_schema.json', schema)
    binding_file = ROOT / 'data/source/resource_bindings.csv'
    previous = [r for r in csv.DictReader(binding_file.open(encoding='utf8')) if not r['id'].startswith('main_ui.')]
    write_csv(binding_file, previous + bindings)
    write_json(ROOT / 'art_source/main_ui/provenance.json', {'reference_root': str(SOURCE), 'assets': records})
    print(f'Imported {len(bindings)} UI assets, {len(heroes)} recruit identities and {len(levels)} dungeon definitions.')


if __name__ == '__main__':
    main()
