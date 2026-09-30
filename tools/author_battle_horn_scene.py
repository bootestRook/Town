"""Source-pinned battle horn: chained header, animated boss, rewards and summon controls."""
from author_building_scenes import Scene
from author_hero_camp_scene import art as camp_art
from author_life_page import art as life_art, button, rich, overlay

def art(s,name,parent,rect,path):
    s.node(name,'TextureRect',parent,rect,f'texture = {s.ext("Texture2D","res://assets/runtime/"+path+".png")}\nexpand_mode = 1\nmouse_filter = 2')

def action(s,name,rect,text):
    button(s,name,'.',rect)
    art(s,'Art',name,(0,0,rect[2],rect[3]),'battle_horn/summon')
    s.label('Text',name,(0,0,rect[2],rect[3]),text,34,1,'Color(1,0.92,0.05,1)')

def main():
    s=Scene('battle_horn_page.gd')
    s.node('Horn','Control',None,(0,0,750,1334),f'script = {s.script}\nclip_contents = true')
    camp_art(s,'Backdrop','.',(0,60,750,440),'backdrop')
    camp_art(s,'Body','.',(0,422,750,912),'body')
    camp_art(s,'Banner','.',(19,85,712,204),'banner')
    art(s,'Building','.',(98,78,177,162),'town/jianzhu_icon_bosszhaohuan')
    s.label('Title','.',(326,112,334,49),'战斗号角 Lv.1',31,1,'Color(1,0.9,0.05,1)')
    s.label('Description','.',(333,208,354,43),'用于召唤boss的建筑',24,1)
    camp_art(s,'UpgradePanel','.',(34,309,684,116),'upgrade_panel')
    camp_art(s,'ChainLeft','.',(84,246,29,104),'chain')
    camp_art(s,'ChainRight','.',(631,246,29,104),'chain')
    s.tex('CostBar','.',(300,349,146,37),'money_bg')
    s.tex('CostIcon','.',(300,344,43,43),'coin')
    s.label('Cost','.',(346,347,92,40),'30k',27,1)
    s.button('Upgrade','.',(536,341,144,52),'升级','upgrade',27)
    s.nodes[-1]+='\ntheme_override_colors/font_color = Color(1,0.9,0.05,1)'
    s.label('Gate','.',(64,326,441,77),'',24,1);s.nodes[-1]+='\nautowrap_mode = 2'
    art(s,'BossGround','.',(41,536,671,339),'battle_horn/boss_ground')
    s.node('Boss','Control','.',(63,380,627,500),f'script = {s.ext("Script","res://src/features/town/presentation/horn_boss_portrait.gd")}\nmouse_filter = 2')
    s.node('Sprite','Sprite2D','Boss',props='position = Vector2(313.5,315)\nflip_h = true')
    for name,x,title,icon in [('Hp',113,'生命值','hp'),('Attack',276,'攻击','attack'),('Defense',429,'防御','defense')]:
        art(s,name+'Bar','.',(x,810,169,55),'hero_detail/'+icon)
        s.label(name,'.',(x+52,811,105,42),'',27,1,'Color(1,1,1,1)')
        s.label(name+'Caption','.',(x+7,846,60,26),title,16,1)
    button(s,'Info','.',(590,811,44,48));art(s,'Icon','Info',(0,0,44,48),'hero_detail/info')
    for name,x,flip in [('Left',16,True),('Right',683,False)]:
        button(s,name,'.',(x,822,54,105));s.nodes[-1]+='\nz_index = 1'
        art(s,'Art',name,(0,0,54,105),'battle_horn/arrow')
        if flip:s.nodes[-1]+='\nflip_h = true'
    art(s,'RewardPanel','.',(0,879,750,195),'battle_horn/rewards')
    s.label('RewardTitle','.',(203,893,344,46),'可获得以下奖励',25,1,'Color(0.765,0.824,0.831,1)')
    s.node('Rewards','ScrollContainer','.',(38,950,678,105),'vertical_scroll_mode = 0\nhorizontal_scroll_mode = 3')
    s.node('Items','HBoxContainer','Rewards',props='layout_mode = 2\ntheme_override_constants/separation = 27')
    action(s,'Sweep',(51,1083,291,94),'扫荡')
    action(s,'Summon',(429,1083,291,94),'免费召唤')
    s.label('Free','.',(483,1064,203,32),'免费次数：4/4',19,1)
    for name,x,text in [('Five',63,'5次'),('Ten',209,'10次')]:
        button(s,name,'.',(x,1174,126,62))
        art(s,'Box',name,(0,0,145,57),'battle_horn/checkbox')
        art(s,'Check',name,(0,0,145,57),'battle_horn/checked');s.nodes[-1]+='\nvisible = false'
        s.label('Text',name,(60,7,58,42),text,24,1)
    s.label('State','.',(97,1048,555,36),'',24,1,'Color(1,0.9,0.05,1)')
    s.label('Footer','.',(118,1257,480,47),'挑战失败或中止战斗将返还召唤材料和次数',20,1,'Color(0.63,0.66,0.65,1)')
    s.tex('Topbar','.',(0,0,750,63),'topbar')
    button(s,'Help','.',(14,-5,64,92),'help')
    art(s,'TicketBar','.',(100,13,126,37),'battle_horn/prop_bar')
    art(s,'TicketIcon','.',(99,9,39,43),'battle_horn/ticket')
    s.label('Tickets','.',(140,9,78,43),'0',26,1,'Color(1,1,1,1)')
    camp_art(s,'GoldBar','.',(253,10,176,44),'coin_bar')
    life_art(s,'DiamondBar','.',(439,10,176,44),'diamond_bar')
    s.label('Coins','.',(297,8,120,48),'60k',25,1,'Color(1,1,1,1)')
    s.label('Diamonds','.',(488,8,115,48),'1155',25,1,'Color(1,1,1,1)')
    button(s,'GoldAdd','.',(253,10,176,44));button(s,'DiamondAdd','.',(439,10,176,44))
    overlay(s,'HelpPanel');s.nodes[-3]+='\nz_index = 2'
    life_art(s,'Panel','HelpPanel',(15,183,720,937),'seat_panel')
    s.label('Title','HelpPanel',(152,243,446,45),'战斗号角说明',29,1)
    rich(s,'Text','HelpPanel',(81,335,588,690),23)
    s.label('DismissHint','HelpPanel',(180,1160,390,46),'点击空白处关闭界面',23,1)
    overlay(s,'Confirm');s.nodes[-3]+='\nz_index = 2'
    s.tex('Panel','Confirm',(28,430,694,440),'dialog')
    s.label('Title','Confirm',(92,457,566,52),'提示',30,1)
    s.label('Text','Confirm',(95,541,560,160),'',25,1);s.nodes[-1]+='\nautowrap_mode = 2'
    s.button('Cancel','Confirm',(103,734,218,76),'取消')
    s.button('Accept','Confirm',(429,734,218,76),'确定')
    s.save('battle_horn_page.tscn')
    reward_card()
    world()

def world():
    s=Scene('horn_world.gd')
    s.node('HornWorld','Node2D',None,props=f'script = {s.script}')
    s.node('Prepare','Control','.',(-185,90,370,125),'mouse_filter = 2')
    art(s,'Panel','Prepare',(0,0,370,125),'battle_horn/prepare')
    s.label('Title','Prepare',(15,16,340,44),'集结中 0/3',26,1,'Color(1,0.9,0.1,1)')
    s.label('Time','Prepare',(50,64,270,42),'00:30',27,1)
    s.node('Chest','Control','.',(-80,-100,160,160),'mouse_filter = 2')
    art(s,'Icon','Chest',(15,0,130,130),'battle_horn/chest')
    s.label('Title','Chest',(0,126,160,34),'BOSS宝箱',25,1)
    s.save('horn_world.tscn')

def reward_card():
    s=Scene();s.node('Reward','Button',None,props='custom_minimum_size = Vector2(100, 105)\nflat = true\nfocus_mode = 0')
    art(s,'Quality','.',(0,0,100,100),'operations/quality_4')
    s.node('Icon','TextureRect','.',(8,6,84,83),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Chance','.',(0,75,100,30),'100%',22,1,'Color(1,1,1,1)')
    s.save('horn_reward.tscn')

if __name__=='__main__':main()
