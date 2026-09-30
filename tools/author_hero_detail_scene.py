"""Fixed HeroPartPnl layout in 720-point source coordinates."""
from author_main_ui_scenes import MainScene


class DetailScene(MainScene):
    def art(self, name, parent, rect, asset):
        self.node(name, 'TextureRect', parent, rect, f'texture = {self.ext("Texture2D", "res://assets/runtime/hero_detail/"+asset+".png")}\nexpand_mode = 1\nmouse_filter = 2')

    def hit(self, name, parent, rect):
        self.node(name, 'Button', parent, rect, 'flat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')


def main():
    s = DetailScene('main_hero_detail.gd')
    s.node('HeroDetail', 'Control', rect=(0,0,720,1280), props=f'script = {s.script}\nmouse_filter = 0\nclip_contents = true')
    s.fill('Base', '.', 'Color(0.031,0.072,0.083,1)')
    s.node('PortraitArea','Control','.',(0,61,720,555),'clip_contents = true\nmouse_filter = 2')
    s.art('Background','PortraitArea',(-992.5,-531,2705,1300),'background_4')
    s.node('Portrait','TextureRect','PortraitArea',(235,131,250,250),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.nodes[-1]+=f'\nscript = {s.ext("Script","res://src/features/town/presentation/hero_idle_portrait.gd")}'
    s.node('Header','Control','.',(0,0,720,61),'mouse_filter = 2')
    s.art('Art','Header',(0,0,720,61),'top')
    for name,x,art in [('Coins',100,'gold'),('Diamonds',322,'diamonds')]:
        s.hit(name,'Header',(x,8,195,47));s.art('Art','Header/'+name,(0,0,195,47),art)
        s.label('Value','Header/'+name,(52,2,110,40),'',26,1,'Color(0.77,0.83,0.82,1)')
    s.hit('Change','.',(34,78,95,39))
    s.nodes[-1]=s.nodes[-1].replace('flat = true','flat = false')
    s.resources.append('[sub_resource type="StyleBoxFlat" id="ChangePill"]\nbg_color = Color(0.29,0.17,0.31,1)\nborder_width_left = 3\nborder_width_top = 3\nborder_width_right = 3\nborder_width_bottom = 3\nborder_color = Color(0.89,0.89,0.7,1)\ncorner_radius_top_left = 20\ncorner_radius_top_right = 20\ncorner_radius_bottom_left = 20\ncorner_radius_bottom_right = 20')
    s.nodes[-1]+='\ntheme_override_styles/normal = SubResource("ChangePill")\ntheme_override_styles/hover = SubResource("ChangePill")\ntheme_override_styles/pressed = SubResource("ChangePill")'
    s.label('Text','Change',(0,0,95,39),'更换英雄',19,1)
    s.hit('Rank','.',(205,74,44,44));s.art('Art','Rank',(0,0,44,44),'rank')
    s.label('Name','.',(262,74,197,45),'',33,1)
    s.label('Level','.',(264,121,193,45),'',36,1)
    s.hit('Element','.',(469,74,44,44))
    s.node('Art','TextureRect','Element',(0,0,44,44),'expand_mode = 1\nmouse_filter = 2')
    s.hit('Wallet','.',(547,71,173,55));s.art('Art','Wallet',(0,0,173,55),'wallet')
    s.label('Value','Wallet',(44,3,101,43),'',29,1)
    for i,(slot,x,y,empty) in enumerate([(1,34,133,1),(2,34,266,4),(4,34,399,5),(7,586,133,6),(6,586,266,7),(8,586,399,8)]):
        s.hit('Slot'+str(slot),'.',(x,y,98,98))
        s.node('Frame','TextureRect','Slot'+str(slot),(0,0,98,98),'expand_mode = 1\nmouse_filter = 2\nvisible = false')
        s.art('Art','Slot'+str(slot),(0,0,98,98),'empty_'+str(empty))
    for name,x in [('Previous',147),('Next',531)]:
        s.hit(name,'.',(x,289,44,94));s.art('Art',name,(9,24,26,49),'arrow')
        if name=='Previous': s.nodes[-1]+='\nflip_h = true'
    s.node('Power','Control','.',(261,473,233,56),'mouse_filter = 2')
    s.art('Icon','Power',(0,0,58,58),'power')
    s.label('Value','Power',(58,-3,175,61),'',48,0,'Color(1,1,1,1)')
    s.nodes[-1]=s.nodes[-1].replace('outline_size = 4','outline_size = 0')+f'\ntheme_override_fonts/font = {s.ext("FontFile","res://assets/runtime/hero_detail/power.fnt")}'
    for i,key in enumerate(['magic','hunger','tired','mood']):
        p='Status'+str(i);s.hit(p,'.',(224+i*75,540,66,73));s.art('Art',p,(0,0,64,64),key)
        s.label('Value',p,(-3,49,72,25),'',23,1,'Color(1,1,1,1)')
    s.hit('EquipmentSettings','.',(621,521,94,94));s.art('Art','EquipmentSettings',(4,0,88,88),'equipment_settings')
    s.label('Text','EquipmentSettings',(-3,67,100,28),'装备设置',21,1)
    background=s.ext('Texture2D','res://assets/runtime/hero_detail/body.png')
    s.resources.append(f'[sub_resource type="AtlasTexture" id="BodyCrop"]\natlas = {background}\nregion = Rect2(0,80,720,805)')
    s.node('ContentBackground','TextureRect','.',(0,616,720,561),'texture = SubResource("BodyCrop")\nexpand_mode = 1\nmouse_filter = 2')
    s.node('Attributes','Control','.',(0,616,720,114),'mouse_filter = 2')
    s.node('Separator','ColorRect','Attributes',(0,110,720,4),'color = Color(0.066,0.13,0.15,1)\nmouse_filter = 2')
    for key,x,label in [('hp',77,'生命值'),('attack',272,'攻击'),('defense',473,'防御')]:
        s.art(key,'Attributes',(x,17,170,58),key)
        s.label('Value','Attributes/'+key,(66,6,100,39),'',29,1,'Color(1,1,1,1)')
        s.label('Text','Attributes/'+key,(0,37,62,24),label,18,1)
    s.hit('Info','Attributes',(650,20,49,49));s.art('Art','Attributes/Info',(0,0,49,49),'info')
    s.node('AttributePage','Control','.',(0,730,720,447),'mouse_filter = 2')
    s.node('Separator','ColorRect','AttributePage',(0,176,720,4),'color = Color(0.066,0.13,0.15,1)\nmouse_filter = 2')
    for i,x in enumerate([86,239,393,546]):
        p='AttributePage/Skill'+str(i);s.hit('Skill'+str(i),'AttributePage',(x,47,89,89))
        s.node('Art','TextureRect',p,(0,0,89,89),'expand_mode = 1\nmouse_filter = 2')
        s.art('Frame',p,(-3,-3,95,95),'skill_frame')
        s.art('Corner',p,(59,-2,33,31),'skill_level')
        s.label('Level',p,(62,0,27,29),'',24,1)
        s.art('Lock',p,(12,12,65,65),'skill_lock');s.nodes[-1]+='\nvisible = false'
    s.node('Promotion','Control','AttributePage',(0,180,720,267),'mouse_filter = 2')
    for i in range(4):s.node('Star'+str(i),'TextureRect','AttributePage/Promotion',(330+i*52,37,52,52),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.hit('Upgrade','AttributePage/Promotion',(214,124,292,93));s.art('Art','AttributePage/Promotion/Upgrade',(0,0,292,93),'star_button')
    s.label('Text','AttributePage/Promotion/Upgrade',(25,19,240,53),'升星',31,1,'Color(1,0.9,0.04,1)')
    s.art('Cost','AttributePage/Promotion/Upgrade',(59,-6,165,35),'cost')
    s.node('Portrait','TextureRect','AttributePage/Promotion/Upgrade/Cost',(2,-7,39,39),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.node('Value','RichTextLabel','AttributePage/Promotion/Upgrade/Cost',(42,0,117,34),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 22')
    s.label('Max','AttributePage/Promotion',(185,130,350,65),'已满星',30,1)
    s.node('CollectionPage','Control','.',(0,730,720,447),'mouse_filter = 2\nvisible = false')
    s.label('Text','CollectionPage',(28,10,664,79),'',25,1);s.nodes[-1]+='\nautowrap_mode = 2'
    s.node('Scroll','ScrollContainer','CollectionPage',props='anchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 20.0\noffset_top = 98.0\noffset_right = -20.0\noffset_bottom = -8.0\nhorizontal_scroll_mode = 0')
    s.container('Rows','CollectionPage/Scroll',None,'VBoxContainer','theme_override_constants/separation = 10\nsize_flags_horizontal = 3')
    bag=s.ext('PackedScene','res://scenes/town/main_hero_bag.tscn')
    s.nodes.append(f'[node name="BagPage" parent="." instance={bag}]\noffset_top = 719.0\noffset_bottom = 1177.0\nvisible = false')
    s.node('Bottom','Control','.',props='anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -103.0\noffset_right = 720.0\nmouse_filter = 2')
    s.art('Art','Bottom',(0,-15,720,118),'bottom')
    for i,label in enumerate(['属性','宠物','神器','背包']):
        s.node('Tab'+str(i),'TextureButton','Bottom',(141*i,0,141,103),f'texture_normal = {s.ext("Texture2D","res://assets/runtime/hero_detail/tab_"+str(i)+".png")}\nignore_texture_size = true\nstretch_mode = 0\nfocus_mode = 0')
        s.label('Text','Bottom/Tab'+str(i),(0,72,141,31),label,24,1,'Color(0.77,0.84,0.81,1)')
    s.hit('Back','Bottom',(597,-79,123,94));s.art('Art','Bottom/Back',(0,0,123,94),'back')
    s.node('Tooltip','Control','.',(150,610,219,174),'visible = false\nmouse_filter = 0')
    s.art('Body','Tooltip',(0,0,219,174),'tip_body')
    s.art('TitleArt','Tooltip',(43,0,133,31),'tip_title')
    s.label('Title','Tooltip',(8,0,203,30),'',22,1)
    s.node('Value','RichTextLabel','Tooltip',(8,36,203,34),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 25')
    s.label('Text','Tooltip',(10,69,199,102),'',21);s.nodes[-1]=s.nodes[-1].replace('vertical_alignment = 1','vertical_alignment = 0')+'\nautowrap_mode = 3'
    s.save('main_hero_detail.tscn')


if __name__ == '__main__': main()
