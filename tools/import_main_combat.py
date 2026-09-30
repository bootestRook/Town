"""Client combat definitions, separate from the local encounter simulation."""
from import_town_reference import read_json


def import_combat(cfg, lang, table):
    join = lambda values: ';'.join(map(str, values)) or '-'
    table('main_passives', [dict(id=str(r['id']), display_name=lang[int(r['skl_name'])],
                                description=lang[r['descriptionid']], kind=r['skl_type'],
                                multiplier=join(r['level_value'])) for r in read_json(cfg/'skill_passive.json')])
    table('main_buffs', [dict(id=str(r['id']), display_name=lang.get(int(r['skl_name']),r['function_name']), description=lang.get(r['descriptionid'],r['remarks']), kind=r['skl_type'], target=r['buff_target'],
                             targets=r['buff_num'], selector=r['target2'], multiplier=join(r['level_value']), chance=join(r['trigger_odds']),
                             duration=join(r['c_time']), interval=int(r['dmg_delay']), boss_immune=r['boss_dmg'],
                             gain=r['gain'], effective=r['effective_type'], stack=r['gongcun'], overwrite=r['fugai']) for r in read_json(cfg/'skill_buff.json')])
    table('main_combat_rules', [dict(id=str(r['id']), value=float(r['value']))
                                for r in read_json(cfg.parent/'baseconf/c25_public.json') if r['id'] in [1077,1078,1174]])
    table('main_battle_gates', [dict(id='boss.'+str(r['id']), cost=r['consume'], dungeon=r['dungeons'], preparation=r['pre_time'])
                               for r in read_json(cfg/'c43_boss_zhaohuan.json')])
    table('main_fairy_loot', [dict(id='fairy.'+str(r['id']), counts=';'.join(f'{weight}:{count}' for weight,count in r['num_pro']),
                                 tiers=';'.join(f'{weight}:{tier}' for weight,tier in r['star_pro']),
                                 pools='|'.join(';'.join(f'{weight}:{item}' for weight,item in pool) for pool in r['drop']))
                            for r in read_json(cfg/'c92_jlmj.json')])
    pets = [dict(id=str(r['id']), display_name=lang[r['skl_name']], trigger=0,
                 cooldown=join(r['cd_time']), delay=r['delayed'], targets=0,
                 multiplier='0', buffs=join(r['buff_list'])) for r in read_json(cfg/'c92_cw_skill.json')]
    pets += [dict(id=str(r['id']), display_name=lang[r['skl_name']], trigger=r['skl_type_base'],
                  cooldown=str(r['cd_time']), delay=r['skl_dmg_time'][0], targets=r['hit_num'],
                  multiplier=join(r['level_value']), buffs=join(r['add_buff'])) for r in read_json(cfg/'c92_cw_skill_base.json')]
    table('main_pet_skills', pets)


def combat_fields(row, element=0, hero=False):
    result = {'element': int(element or row.get('yszy', 0)), 'frequency': 1.0 if hero else float(row.get('freq', 1))}
    for key in ['hit', 'dodge', 'critical', 'bonus', 'toughness', 'blood', 'hurt', 'reduction']:
        value = str(row.get(key + '_up' if hero else key, 0))
        result[key] = sum(map(float, value.split('|'))) / len(value.split('|'))
    if hero:
        values = str(row['freq']).split('|')
        result['frequency'] = sum(map(float, values)) / len(values)
    return result
