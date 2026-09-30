"""Normalize source pet, artifact, inventory and permanent store definitions."""
from import_town_reference import read_json


def import_collections(cfg, lang, table, asset):
    read = lambda name: read_json(cfg / (name + '.json'))
    pairs = lambda values: ';'.join(f'{a}:{b}' for a, b in values) or '-'
    images = {}

    def picture(path):
        if path not in images:
            images[path] = asset('collection_' + str(len(images)), path)
        return images[path]

    table('main_pets', [dict(id=str(r['id']), display_name=lang[r['name']], star=r['star'],
                            family=r['cw_type'], quality=r['color'], max_level=r['lv_max'],
                            next_id=r['next_id'], previous_id=r['previous_star'],
                            consume=r['up_consume'][0] if r['up_consume'] else 0,
                            count=r['up_consume'][1] if r['up_consume'] else 0,
                            dismantle=pairs([r['break_item']]), description=lang[r['skill_info']],
                            skills='|'.join(';'.join(map(str, pair)) for pair in [r['skill'], r['skill2']] if pair),
                            resource_id=picture('tmp/pet/icon/' + r['path'])) for r in read('c92_cw')])
    table('main_pet_levels', [dict(id=str(r['id']), city_level=r['lv'], cost=pairs(r['gold']),
                                  gold_cost=pairs(r['gold_2']), refund=pairs(r['back']), gold_refund=pairs(r['back_2']),
                                  hp=r['hp'], attack=r['att'], defense=r['def'],
                                  gold_hp=r['hp_2'], gold_attack=r['att_2'], gold_defense=r['def_2']) for r in read('c92_cw_lv')])
    table('main_artifacts', [dict(id=str(r['id']), display_name=lang[r['name']], exclusive=r['hero_zs'],
                                 growth_min=r['range_cz'][0], growth_max=r['range_cz'][1],
                                 refine_cost=pairs([r['xlxh']]),
                                 resource_id=picture('tmp/artifact/icon/' + r['pic'])) for r in read('c102_shenqi')])
    table('main_artifact_levels', [dict(id=str(r['id']), stats=pairs(r['basic_attribute']), gold_stats=pairs(r['basic_attribute_4']),
                                       cost=pairs(r['up_consume']), gold_cost=pairs(r['up_consume_4']),
                                       refund=pairs(r['back_perfect']), gold_refund=pairs(r['back_perfect_4']),
                                       breakthrough=r['breakthrough']) for r in read('c102_shenqi_upgradation')])
    table('main_artifact_qualities', [dict(id=str(r['id']), growth_min=r['cz'][0], growth_max=r['cz'][1],
                                          dismantle=pairs(r['back'])) for r in read('c102_shenqi_pz')])
    table('main_item_uses', [dict(id=str(r['id']), display_name=lang[r['name']], kind=r['type_id'],
                                 value=r['use_id'] or '-', amount=r['key_num'] or '-', description=lang.get(r['info'], r['remark2']),
                                 resource_id=picture('tmp/prop/' + r['pic'].removesuffix('.png')))
                            for r in read('c22_item') if r['canuse'] and r['type_id'] in [6, 22, 30, 36, 39]])
    products = {r['id']: r for r in read('c70_product_list')}
    item_defs = {r['id']: r for r in read('c21_resouce') + read('c22_item')}

    def gift_picture(rewards):
        keys = [int(pair.split(':')[0]) for pair in rewards.split(';') if ':' in pair]
        key = next((key for key in keys if key not in [101, 102]), keys[0])
        return picture('tmp/prop/' + item_defs[key]['pic'].removesuffix('.png'))

    gifts = [dict(id='gift.'+str(r['id']), display_name=lang[int(r['name'])], category=r['shoptype1'],
                  rewards=r['itemnum'], price=products[int(r['productid'])]['CNY']/100.0,
                  limit=r['allbuytime'], minimum=r['unlock'][0], maximum=r['unlock'][1],
                  order=r['index'], resource_id=gift_picture(r['itemnum']), start_day=0, end_day=0)
             for r in read('c70_libao2')]
    offers = {r['id']: r for r in read('c70_thlb')}
    for period in read('c70_thlb_time'):
        for index, key in enumerate(period['goods']):
            r = offers[key]
            gifts.append(dict(id='special.'+str(period['id'])+'.'+str(key), display_name=lang[r['name']], category=6,
                              rewards=pairs(r['gift']), price=products[int(r['productid'])]['CNY']/100.0,
                              limit=r['allbuytime'], minimum=r['unlock'][0], maximum=r['unlock'][1], order=index,
                              resource_id=gift_picture(pairs(r['gift'])), start_day=period['day_start'], end_day=period['day_end']))
    table('main_shop_gifts', gifts)
