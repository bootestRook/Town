"""Fixed FightSetPnl skeleton; runtime only instantiates hero list items."""
from author_building_scenes import Scene
from author_life_page import button

def art(s,name,parent,rect,path):
    s.node(name,'TextureRect',parent,rect,f'texture = {s.ext("Texture2D","res://assets/runtime/"+path+".png")}\nexpand_mode = 1\nmouse_filter = 2')

def action(s,name,parent,rect,text,asset,size=24):
    button(s,name,parent,rect)
    path=name if parent=='.' else parent+'/'+name
    art(s,'Art',path,(0,0,rect[2],rect[3]),asset)
    s.label('Text',path,(0,0,rect[2],rect[3]),text,size,1,'Color(1,0.94,0.12,1)' if asset.endswith('move') else 'Color(0.94,0.94,0.8,1)')

def main():
    s=Scene('main_map_dispatch.gd')
    s.node('MapDispatch','Control',None,(0,0,720,1280),f'script = {s.script}')
    button(s,'Shade','.',(0,0,720,1280))
    s.node('Tint','ColorRect','Shade',(0,0,720,1280),'color = Color(0,0,0,0.74)\nmouse_filter = 2')
    s.node('Panel','Control','.',(0,40,720,1145),'mouse_filter = 0')
    art(s,'Frame','Panel',(0,0,720,1145),'dispatch/frame')
    s.label('Title','Panel',(185,40,350,50),'地图派遣',30,1,'Color(1,0.96,0,1)')
    button(s,'Help','Panel',(80,38,56,57));art(s,'Art','Panel/Help',(0,0,56,57),'recruitment/help')
    for area,name,x in [('town','主城',82),('field','兽人密林',222),('field2','亡灵墓地',362),('field3','魔族战场',502)]:
        action(s,'All'+area,'Panel',(x,127,131,54),name,'dispatch/tab')
    for area,name,x,y in [('town','主城',62,241),('field3','魔族战场',364,241),('field','兽人密林',62,669),('field2','亡灵墓地',364,669)]:
        s.node(area,'Control','Panel',(x,y,292,369),'mouse_filter = 1')
        p='Panel/'+area
        art(s,'Ground',p,(0,0,292,369),'dispatch/'+area)
        if area=='town':
            art(s,'TitleArt',p,(83,-18,125,37),'dispatch/town_title')
            s.label('Title',p,(128,-18,70,37),name,22,1,'Color(0.75,0.82,0.84,1)')
        else:
            art(s,'TitleArt',p,(31,-18,230,37),'dispatch/title')
            art(s,'PowerArt',p,(146,-17,114,35),'dispatch/power')
            art(s,'PowerIcon',p,(146,-17,32,34),'main_ui/power_icon')
            s.label('Title',p,(34,-18,110,37),name,22,1,'Color(0.75,0.82,0.84,1)')
            s.label('Power',p,(178,-17,73,35),'0',23,1,'Color(1,1,1,1)')
        s.node('Scroll','ScrollContainer',p,(11,36,270,320),'horizontal_scroll_mode = 0\nvertical_scroll_mode = 3\nscroll_deadzone = 12\nmouse_filter = 0')
        s.node('Grid','GridContainer',p+'/Scroll',props='layout_mode = 2\ncolumns = 3\ntheme_override_constants/h_separation = 8\ntheme_override_constants/v_separation = 12')
        art(s,'Fade',p,(8,320,277,49),'dispatch/fade')
        action(s,'Move',p,(46,158,200,68),'派遣至'+name,'dispatch/move',22)
        s.node('Locked','ColorRect',p,(3,3,286,363),'color = Color(0,0,0,0.6)\nmouse_filter = 2')
        s.label('Text',p+'/Locked',(14,120,258,115),'',23,1);s.nodes[-1]+='\nautowrap_mode = 2'
    s.label('Hint','Panel',(100,1067,520,42),'点击英雄后可选择要派遣的地区',20,1)
    s.label('DismissHint','.',(130,1200,460,42),'点击空白处关闭界面',22,1,'Color(0.75,0.82,0.84,1)')
    s.node('Popup','Control','.',(0,0,720,1280),'visible = false')
    button(s,'Dismiss','Popup',(0,0,720,1280))
    s.node('Tint','ColorRect','Popup/Dismiss',(0,0,720,1280),'color = Color(0,0,0,0.72)\nmouse_filter = 2')
    s.node('Box','Control','Popup',(30,400,660,480),'mouse_filter = 0')
    s.node('Frame','NinePatchRect','Popup/Box',(0,0,660,480),f'texture = {s.ext("Texture2D","res://assets/runtime/operations/dialog.png")}\npatch_margin_left = 80\npatch_margin_right = 80\npatch_margin_top = 128\npatch_margin_bottom = 65\nmouse_filter = 2')
    s.label('Title','Popup/Box',(90,34,480,50),'提示',29,1)
    s.node('Scroll','ScrollContainer','Popup/Box',(90,105,480,244),'horizontal_scroll_mode = 0\nscroll_deadzone = 12')
    s.label('Text','Popup/Box/Scroll',(0,0,480,244),'',23,0);s.nodes[-1]+='\nlayout_mode = 2\nsize_flags_horizontal = 3\nautowrap_mode = 2\ncustom_minimum_size = Vector2(480,244)'
    action(s,'Cancel','Popup/Box',(83,370,200,68),'取消','dispatch/move')
    action(s,'Accept','Popup/Box',(377,370,200,68),'确定','dispatch/move')
    s.save('main_map_dispatch.tscn')
    s=Scene('main_dispatch_card.gd')
    s.node('DispatchCard','Control',None,(0,0,83,108),f'script = {s.script}\ncustom_minimum_size = Vector2(83,108)\nmouse_filter = 1')
    card=s.ext('PackedScene','res://scenes/town/main_hero_library_card.tscn')
    s.nodes.append(f'[node name="Card" parent="." instance={card}]\nscale = Vector2(0.5,0.5)')
    art(s,'Selected','.',(-4,-4,91,114),'dispatch/selected')
    art(s,'Warning','.',(63,83,18,18),'dispatch/warning')
    s.save('main_dispatch_card.tscn')

if __name__=='__main__': main()
