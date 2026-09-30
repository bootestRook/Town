"""Author editable, fixed main interface scenes using source artwork."""
from author_building_scenes import Scene


class MainScene(Scene):
    def art(self, name, parent, rect, asset):
        self.node(name, 'TextureRect', parent, rect,
                  f'texture = {self.ext("Texture2D", "res://assets/runtime/main_ui/"+asset+".png")}\nexpand_mode = 1\nmouse_filter = 2')

    def fill(self, name, parent, color):
        self.node(name, 'ColorRect', parent, props=f'anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ncolor = {color}\nmouse_filter = 2')

    def container(self, name, parent, rect, kind='VBoxContainer', props=''):
        self.node(name, kind, parent, rect, 'mouse_filter = 2\n' + props)


def shell():
    s=MainScene('main_hud.gd')
    font=s.ext('FontFile','res://assets/runtime/operations/font.ttf')
    for name,color,border in [('ScrollTrack','0.025,0.055,0.065,1','0.01,0.02,0.025,1'),('ScrollThumb','0.2,0.37,0.39,1','0.04,0.08,0.09,1'),('Input','0.05,0.1,0.13,1','0.28,0.43,0.45,1'),('InputFocus','0.05,0.1,0.13,1','0.91,0.76,0.37,1')]:
        s.resources.append(f'[sub_resource type="StyleBoxFlat" id="{name}"]\nbg_color = Color({color})\nborder_width_left = 2\nborder_width_top = 2\nborder_width_right = 2\nborder_width_bottom = 2\nborder_color = Color({border})\ncontent_margin_left = 5.0\ncontent_margin_right = 5.0\ncontent_margin_top = 6.0\ncontent_margin_bottom = 6.0')
    s.resources.append(f'[sub_resource type="Theme" id="Theme"]\ndefault_font = {font}\ndefault_font_size = 24\nLabel/colors/font_color = Color(0.88,0.9,0.84,1)\nLabel/colors/font_outline_color = Color(0.01,0.02,0.02,1)\nLabel/constants/outline_size = 3\nLineEdit/colors/font_color = Color(0.88,0.9,0.84,1)\nLineEdit/colors/caret_color = Color(0.95,0.83,0.49,1)\nLineEdit/styles/normal = SubResource("Input")\nLineEdit/styles/focus = SubResource("InputFocus")\nVScrollBar/styles/scroll = SubResource("ScrollTrack")\nVScrollBar/styles/grabber = SubResource("ScrollThumb")\nVScrollBar/styles/grabber_highlight = SubResource("ScrollThumb")\nVScrollBar/styles/grabber_pressed = SubResource("ScrollThumb")')
    s.node('MainHUD','Control',props=f'anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\nscript = {s.script}\ntheme = SubResource("Theme")')
    s.node('Stage','Control','.',(0,0,720,1280),'mouse_filter = 2')
    s.node('Top','Control','Stage',(0,0,720,84),'mouse_filter = 0')
    s.art('Art','Stage/Top',(0,0,720,84),'top')
    s.node('Profile','Button','Stage/Top',(4,4,72,74),'flat = true\nfocus_mode = 0')
    s.art('Portrait','Stage/Top/Profile',(5,6,62,62),'avatar')
    s.art('Frame','Stage/Top/Profile',(0,0,72,70),'avatar_frame')
    s.label('Name','Stage/Top/Profile',(0,60,74,15),'',10,1)
    for name,x,w,asset in [('Coins',80,132,'coins'),('Diamonds',220,137,'diamonds'),('Energy',366,145,'energy')]:
        s.node(name,'Button','Stage/Top',(x,10,w,42),'flat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
        s.art('Art','Stage/Top/'+name,(0,0,w,42),asset)
        left=28 if name=='Energy' else 50
        s.label('Value','Stage/Top/'+name,(left,0,w-left-5,39),'',22 if name=='Energy' else 23,0,'Color(0.77,0.83,0.82,1)')
    s.art('RedDot','Stage/Top/Energy',(17,-7,20,20),'red_dot')
    s.art('CombatIcon','Stage/Top',(83,51,32,32),'power_icon')
    s.label('Combat','Stage/Top',(123,51,135,30),'',24,0,'Color(1,0.87,0.03,1)')
    panels=s.ext('PackedScene','res://scenes/town/main_panels.tscn')
    s.nodes.append(f'[node name="Panels" parent="Stage" instance={panels}]\noffset_top = 86.0\noffset_bottom = 1177.0\nvisible = false')
    roster=s.ext('PackedScene','res://scenes/town/main_hero_roster.tscn')
    s.nodes.append(f'[node name="HeroRoster" parent="Stage" instance={roster}]\noffset_top = 572.0\noffset_bottom = 1172.0\nvisible = false')
    s.node('Bottom','Control','Stage',props='anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -108.0\noffset_right = 720.0\nmouse_filter = 0')
    s.art('Art','Stage/Bottom',(0,-24,720,132),'bottom')
    for i,label in enumerate(['玩法','地下城','英雄','招募','商城']):
        s.node('Nav'+str(i),'TextureButton','Stage/Bottom',(4+143*i,5,141,103),f'texture_normal = {s.ext("Texture2D",f"res://assets/runtime/main_ui/nav_{i}.png")}\ntexture_pressed = {s.ext("Texture2D",f"res://assets/runtime/main_ui/nav_{i}_selected.png")}\nignore_texture_size = true\nstretch_mode = 0\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
        s.label('Text','Stage/Bottom/Nav'+str(i),(0,72,141,30),label,25,1,'Color(0.78,0.83,0.8,1)')
        s.art('RedDot','Stage/Bottom/Nav'+str(i),(113,6,21,21),'red_dot');s.nodes[-1]+='\nvisible = false'
    recruitment=s.ext('PackedScene','res://scenes/town/main_recruitment.tscn')
    s.nodes.append(f'[node name="Recruitment" parent="Stage" instance={recruitment}]\nvisible = false')
    overlay=s.ext('PackedScene','res://scenes/town/main_recruitment_overlay.tscn')
    s.nodes.append(f'[node name="RecruitOverlay" parent="Stage" instance={overlay}]\nvisible = false')
    detail=s.ext('PackedScene','res://scenes/town/main_hero_detail.tscn')
    management=s.ext('PackedScene','res://scenes/town/main_hero_management.tscn')
    s.nodes.append(f'[node name="HeroManagement" parent="Stage" instance={management}]\nvisible = false')
    s.nodes.append(f'[node name="HeroDetail" parent="Stage" instance={detail}]\nvisible = false')
    shop=s.ext('PackedScene','res://scenes/town/main_diamond_shop.tscn')
    s.nodes.append(f'[node name="DiamondShop" parent="Stage" instance={shop}]\nvisible = false')
    dialogs=s.ext('PackedScene','res://scenes/town/main_dialogs.tscn')
    s.nodes.append(f'[node name="Dialogs" parent="Stage" instance={dialogs}]\nvisible = false')
    equipment=s.ext('PackedScene','res://scenes/town/main_equipment_detail.tscn')
    s.nodes.append(f'[node name="EquipmentDetail" parent="Stage" instance={equipment}]\nvisible = false')
    tooltip=s.ext('PackedScene','res://scenes/town/main_skill_tooltip.tscn')
    s.nodes.append(f'[node name="SkillTooltip" parent="Stage" instance={tooltip}]\nvisible = false')
    s.label('Notice','Stage',(36,1045,648,44),'',24,1)
    s.nodes[-1]+='\nvisible = false\nautowrap_mode = 2\nz_index = 12'
    s.save('main_hud.tscn')


def panels():
    s=MainScene('main_panels.gd')
    s.node('Panels','Control',rect=(0,0,720,1091),props=f'script = {s.script}\nmouse_filter = 0\nclip_contents = true')
    s.fill('Base','.','Color(0.12,0.22,0.24,1)')
    s.tex('Body','.',(0,0,720,1200),'exchange_body')
    s.node('Banner','TextureRect','.',(0,40,720,350),'expand_mode = 1\nstretch_mode = 6\nmouse_filter = 2')
    s.tex('Header','.',(0,0,720,64),'topbar');s.label('Title','.',(110,3,500,52),'',31,1)
    s.button('Close','.',(643,1,67,62),'','back')
    s.label('Summary','.',(25,73,670,50),'',24,1)
    s.node('Scroll','ScrollContainer','.',props='anchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 17.0\noffset_top = 136.0\noffset_right = -17.0\noffset_bottom = -144.0\nhorizontal_scroll_mode = 0')
    s.container('Grid','Scroll',None,'GridContainer','columns = 3\nsize_flags_horizontal = 3\ntheme_override_constants/h_separation = 14\ntheme_override_constants/v_separation = 16')
    s.node('Footer','Control','.',props='anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -135.0\noffset_right = 720.0\nmouse_filter = 2')
    s.tex('FooterArt','Footer',(0,0,720,135),'exchange_bottom')
    for name,x,label in [('Secondary',22,''),('Primary',385,'')]:
        s.button(name,'Footer',(x,51,313,69),label,size=24)
    s.label('FooterText','Footer',(20,4,680,44),'',22,1)
    battle=s.ext('PackedScene','res://scenes/town/main_battle.tscn')
    s.nodes.append(f'[node name="Battle" parent="." instance={battle}]\nvisible = false\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_right = 0.0\noffset_bottom = 0.0')
    s.save('main_panels.tscn')


def card():
    s=MainScene()
    s.node('Card','Button',rect=(0,0,212,264),props='custom_minimum_size = Vector2(212,264)\nflat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
    s.art('Art','.',(0,0,212,254),'hero_card')
    s.node('Portrait','TextureRect','.',(34,25,144,144),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Title','.',(8,176,196,36),'',25,1)
    s.label('Detail','.',(8,214,196,43),'',20,1)
    s.save('main_card.tscn')
    s=MainScene();s.node('Mode','Button',rect=(0,0,686,217),props='custom_minimum_size = Vector2(686,217)\nflat = true\nfocus_mode = 0')
    s.node('Art','TextureRect','.',(0,0,686,217),'expand_mode = 1\nmouse_filter = 2')
    s.label('Title','.',(35,22,410,55),'',33)
    s.label('Detail','.',(35,143,500,42),'',23)
    s.save('main_mode_card.tscn')


def dialogs():
    s=MainScene('main_dialogs.gd');s.node('Dialogs','Control',rect=(0,0,720,1280),props=f'script = {s.script}\nmouse_filter = 0')
    s.fill('Shade','.','Color(0,0,0,0.7)')
    s.node('Panel','Control','.',(0,140,720,970),'mouse_filter = 0')
    s.tex('Art','Panel',(15,0,690,960),'dialog')
    s.label('Title','Panel',(170,57,380,61),'',31,1)
    s.button('Close','Panel',(635,10,64,60),'','back')
    s.node('Portrait','TextureRect','Panel',(284,140,152,152),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Text','Panel',(62,316,596,205),'',27,1);s.nodes[-1]+='\nautowrap_mode = 2'
    s.node('NameInput','LineEdit','Panel',(134,304,452,53),'visible = false\nmax_length = 12\nalignment = 1\ntheme_override_font_sizes/font_size = 24')
    s.node('Scroll','ScrollContainer','Panel',(48,522,624,238),'horizontal_scroll_mode = 0')
    s.container('Rows','Panel/Scroll',None,'VBoxContainer','size_flags_horizontal = 3\ntheme_override_constants/separation = 12')
    for name,rect in [('Action',(62,786,284,66)),('Alternate',(374,786,284,66)),('Third',(62,868,284,66)),('Fourth',(374,868,284,66))]:
        s.button(name,'Panel',rect,'',size=23)
    s.node('Confirm','Control','.',(0,0,720,1280),'visible = false\nmouse_filter = 0')
    s.fill('Shade','Confirm','Color(0,0,0,0.76)')
    s.tex('Art','Confirm',(38,410,644,422),'dialog')
    s.label('Text','Confirm',(86,465,548,155),'',26,1);s.nodes[-1]+='\nautowrap_mode = 2'
    s.button('Cancel','Confirm',(98,690,226,70),'取消',size=25)
    s.button('Accept','Confirm',(396,690,226,70),'确定',size=25)
    s.save('main_dialogs.tscn')
    s=MainScene();s.node('Row','Button',rect=(0,0,600,64),props='custom_minimum_size = Vector2(600,64)\nflat = true\nfocus_mode = 0')
    s.tex('Art','.',(0,0,600,64),'condition_banner');s.label('Text','.',(14,4,572,56),'',23,1)
    s.button('Toggle','.',(464,5,128,54),'',size=22);s.nodes[-3]+='\nvisible = false'
    s.save('main_action_row.tscn')


def battle():
    s=MainScene('main_battle.gd');s.node('Battle','Control',rect=(0,0,720,1091),props=f'script = {s.script}\nmouse_filter = 0')
    s.fill('Base','.','Color(0.04,0.1,0.13,1)')
    s.art('Background','.',(0,0,720,1091),'dungeon_bg')
    s.tex('TitleArt','.',(0,0,720,64),'topbar');s.label('Title','.',(50,8,620,50),'',30,1)
    s.label('Time','.',(160,70,400,42),'',25,1)
    for group,y in [('Enemies',144),('Allies',483)]:
        s.node(group,'Control','.',(0,y,720,245),'mouse_filter = 2')
        for i in range(5):
            p=group+'/Unit'+str(i);s.node('Unit'+str(i),'Control',group,(14+140*i,0,130,215),'mouse_filter = 2')
            s.art('Card',p,(0,0,130,166),'hero_card')
            s.node('Portrait','TextureRect',p,(12,13,106,106),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
            s.label('Name',p,(0,132,130,35),'',20,1)
            track=s.ext('Texture2D','res://assets/runtime/heroes/ui/'+('monster_health_track' if group=='Enemies' else 'health_track')+'.png')
            fill=s.ext('Texture2D','res://assets/runtime/heroes/ui/health_fill.png')
            tint='Color(0.8,0,0.2,1)' if group=='Enemies' else 'Color(0.266667,0.890196,0.427451,1)'
            s.node('HP','TextureProgressBar',p,(3,172,58,9),f'scale = Vector2(2.13793,1.888889)\ntexture_under = {track}\ntexture_progress = {fill}\ntexture_progress_offset = Vector2(2,2)\ntint_progress = {tint}\nstep = 0.0\nmouse_filter = 2')
            s.label('Value',p,(0,193,130,28),'',16,1)
    s.label('Result','.',(100,382,520,65),'',40,1,'Color(1,0.88,0.25,1)')
    s.label('Log','.',(42,744,636,150),'',20,1)
    s.node('Footer','Control','.',props='anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -112.0\noffset_right = 720.0\nmouse_filter = 2')
    s.button('Back','Footer',(28,22,200,68),'撤退',size=24)
    s.button('Speed','Footer',(260,22,200,68),'一倍速',size=24)
    s.button('Claim','Footer',(492,22,200,68),'领取奖励',size=24)
    s.save('main_battle.tscn')


if __name__=='__main__':
    card(); dialogs(); battle(); panels(); shell()
