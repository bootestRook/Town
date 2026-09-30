"""Fixed 750x1334 hero camp, matching the supplied source page."""
from author_building_scenes import Scene
from author_life_page import art as life_art, button, rich, overlay


def art(s, name, parent, rect, asset):
    s.node(name,'TextureRect',parent,rect,f'texture = {s.ext("Texture2D", "res://assets/runtime/hero_camp/"+asset+".png")}\nexpand_mode = 1\nmouse_filter = 2')


def main():
    s = Scene('hero_camp_page.gd')
    s.node('Camp','Control',None,(0,0,750,1334),f'script = {s.script}\nclip_contents = true')
    art(s,'Backdrop','.',(0,60,750,440),'backdrop')
    art(s,'Body','.',(0,422,750,921),'body')
    art(s,'Banner','.',(19,85,712,204),'banner')
    s.node('Building','TextureRect','.',(96,48,210,217),f'texture = {s.ext("Texture2D","res://assets/runtime/town/jianzhu_icon_gongyu.png")}\nexpand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Title','.',(318,111,338,48),'英雄营地 Lv.5',31,1,'Color(1,0.9,0.05,1)')
    s.label('Description','.',(340,206,344,43),'可容纳英雄居住的建筑',23,1)
    art(s,'UpgradePanel','.',(34,307,684,116),'upgrade_panel')
    art(s,'ChainLeft','.',(84,246,29,104),'chain')
    art(s,'ChainRight','.',(631,246,29,104),'chain')
    s.tex('CostIcon','.',(236,338,45,43),'coin')
    s.label('Cost','.',(286,337,160,48),'150k',28,1)
    s.button('Upgrade','.',(517,338,148,57),'升级','upgrade',29)
    s.label('Max','.',(180,337,390,48),'已达最高等级',29,1,'Color(1,0.9,0.05,1)');s.nodes[-1]+='\nvisible = false'
    art(s,'Section','.',(193,465,367,62),'section')
    s.label('SectionTitle','.',(233,477,290,38),'英雄营地',28,1)
    art(s,'CapacityPanel','.',(16,532,716,125),'capacity')
    s.label('CapacityTitle','.',(189,539,375,43),'当前可容纳的英雄',25,1,'Color(0.765,0.824,0.831,1)')
    rich(s,'Capacity','.',(208,590,338,52),38)
    s.node('Preview','Control','.',(0,670,750,455),'mouse_filter = 2')
    art(s,'LineLeft','Preview',(139,7,159,23),'divider');s.nodes[-1]+='\nflip_h = true'
    art(s,'LineRight','Preview',(453,7,159,23),'divider')
    s.label('Caption','Preview',(326,0,100,38),'预览',24,1,'Color(0.765,0.824,0.831,1)')
    for i,y in enumerate([48,256]):
        name=f'Row{i}'
        s.node(name,'Control','Preview',(20,y,713,198),'mouse_filter = 2')
        art(s,'Background','Preview/'+name,(0,0,713,198),'preview')
        s.label('Caption','Preview/'+name,(40,15,180,39),'等级提升至',25)
        s.label('Level','Preview/'+name,(55,54,115,124),'6',80,1,'Color(0.765,0.824,0.831,1)')
        art(s,'People','Preview/'+name,(330,25,50,42),'people')
        s.label('Description','Preview/'+name,(385,26,280,42),'英雄容纳上限提升',25)
        s.label('Before','Preview/'+name,(350,97,86,55),'7',36,1,'Color(1,1,1,1)')
        s.label('After','Preview/'+name,(501,97,86,55),'8',36,1,'Color(1,1,1,1)')
    art(s,'Bottom','.',(0,1217,750,117),'bottom')
    s.tex('Topbar','.',(0,0,750,63),'topbar')
    button(s,'Help','.',(14,-5,64,92),'help')
    art(s,'GoldBar','.',(85,10,176,44),'coin_bar')
    life_art(s,'DiamondBar','.',(275,10,176,44),'diamond_bar')
    s.label('Coins','.',(125,8,124,48),'60k',25,1,'Color(1,1,1,1)')
    s.label('Diamonds','.',(324,8,115,48),'1155',25,1,'Color(1,1,1,1)')
    button(s,'GoldAdd','.',(85,10,176,44))
    button(s,'DiamondAdd','.',(275,10,176,44))
    overlay(s,'HelpPanel')
    life_art(s,'Panel','HelpPanel',(15,320,720,690),'seat_panel')
    s.label('Title','HelpPanel',(182,372,386,46),'英雄营地说明',28,1)
    rich(s,'Text','HelpPanel',(96,472,558,430),26)
    s.label('DismissHint','HelpPanel',(180,1080,390,46),'点击空白处关闭界面',23,1)
    s.save('hero_camp_page.tscn')


if __name__ == '__main__': main()
