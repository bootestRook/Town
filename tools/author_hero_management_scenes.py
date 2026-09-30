"""Fixed reference HeroStandby pages and reusable dynamic item templates."""
from author_hero_detail_scene import DetailScene


class ManagementScene(DetailScene):
    def art(self, name, parent, rect, asset):
        group, key = asset.split('.', 1) if '.' in asset else ('hero_management', asset)
        self.node(name, 'TextureRect', parent, rect, f'texture = {self.ext("Texture2D", "res://assets/runtime/"+group+"/"+key+".png")}\nexpand_mode = 1\nmouse_filter = 2')

    def portrait(self, name, parent, rect):
        self.node(name,'TextureRect',parent,rect,f'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2\nscript = {self.ext("Script","res://src/features/town/presentation/hero_idle_portrait.gd")}')

    def scroll(self,name,top,bottom,columns=0):
        self.node(name,'ScrollContainer','.',props=f'anchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 14.0\noffset_top = {top}.0\noffset_right = -14.0\noffset_bottom = -{bottom}.0\nhorizontal_scroll_mode = 0\nvertical_scroll_mode = 3')
        if columns:self.container('Grid',name,None,'GridContainer',f'columns = {columns}\nsize_flags_horizontal = 3\ntheme_override_constants/h_separation = 10\ntheme_override_constants/v_separation = 14')
        else:self.container('Rows',name,None,'VBoxContainer','size_flags_horizontal = 3\ntheme_override_constants/separation = 10')


def main():
    s=ManagementScene('main_hero_management.gd')
    s.node('HeroManagement','Control',rect=(0,0,720,1280),props=f'script = {s.script}\nmouse_filter = 0\nclip_contents = true')
    s.fill('Base','.','Color(0.039,0.09,0.105,1)')
    s.node('Formation','Control','.',(0,64,720,554),'mouse_filter = 2')
    s.art('Background','Formation',(0,0,720,554),'camp')
    s.art('CountArt','Formation',(248,18,224,39),'count')
    s.node('Count','RichTextLabel','Formation',(248,24,224,34),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 22')
    for i in range(15):
        parent='Formation/Slot'+str(i)
        s.hit('Slot'+str(i),'Formation',(14+(i%5)*139,108+(i//5)*150,137,144))
        s.art('Pedestal',parent,(0,69,137,75),'pedestal')
        s.art('Add',parent,(11,78,116,58),'add')
        s.portrait('Portrait',parent,(13,5,112,112))
        s.art('Lock',parent,(32,28,74,75),'lock')
        s.label('Unlock',parent,(-12,101,161,32),'',20,1,'Color(1,0.31,0.04,1)')
    s.node('Filters','Control','.',(14,625,692,68),'mouse_filter = 2')
    for i in range(5):
        p='Filters/Filter'+str(i);s.hit('Filter'+str(i),'Filters',(i*82,0,62,62))
        if i==0:
            s.resources.append('[sub_resource type="StyleBoxFlat" id="AllFilter"]\nbg_color = Color(0.29,0.17,0.31,1)\nborder_width_left = 3\nborder_width_top = 3\nborder_width_right = 3\nborder_width_bottom = 3\nborder_color = Color(0.04,0.06,0.07,1)\ncorner_radius_top_left = 31\ncorner_radius_top_right = 31\ncorner_radius_bottom_left = 31\ncorner_radius_bottom_right = 31')
            s.nodes[-1]=s.nodes[-1].replace('flat = true','flat = false')+'\ntheme_override_styles/normal = SubResource("AllFilter")\ntheme_override_styles/hover = SubResource("AllFilter")\ntheme_override_styles/pressed = SubResource("AllFilter")'
            s.label('Text',p,(0,0,62,62),'ALL',22,1)
        else:s.art('Art',p,(4,4,54,54),'hero_roster.element_'+str(i))
        s.art('Selected',p,(-1,-1,64,64),'filter_selected')
    s.hit('Quick','Filters',(540,8,138,47))
    s.resources.append('[sub_resource type="StyleBoxFlat" id="QuickPill"]\nbg_color = Color(0.29,0.17,0.31,1)\nborder_width_left = 2\nborder_width_top = 2\nborder_width_right = 2\nborder_width_bottom = 2\nborder_color = Color(0.89,0.89,0.7,1)\ncorner_radius_top_left = 24\ncorner_radius_top_right = 24\ncorner_radius_bottom_left = 24\ncorner_radius_bottom_right = 24')
    s.nodes[-1]=s.nodes[-1].replace('flat = true','flat = false')+'\ntheme_override_styles/normal = SubResource("QuickPill")\ntheme_override_styles/hover = SubResource("QuickPill")\ntheme_override_styles/pressed = SubResource("QuickPill")'
    s.label('Text','Filters/Quick',(0,0,138,47),'快捷上阵',23,1)
    s.scroll('FormationScroll',706,112,4)
    s.node('Training','Control','.',(14,76,692,211),'mouse_filter = 2')
    for i in range(8):
        p='Training/Category'+str(i);s.hit('Category'+str(i),'Training',((i%4)*175,(i//4)*75,166,63));s.art('Art',p,(0,0,166,63),'category_selected' if i==0 else 'category')
        if i==0:s.label('Text',p,(0,0,166,63),'升星',27,1,'Color(1,0.92,0.05,1)')
        else:s.art('Lock',p,(55,4,56,56),'lock')
    s.art('CountArt','Training',(3,169,205,35),'count');s.label('Count','Training',(3,166,205,40),'',23,1)
    s.scroll('TrainingScroll',299,112)
    s.label('CatalogTitle','.',(100,78,520,36),'全部英雄',23,1)
    s.scroll('CatalogScroll',117,188,4)
    s.node('CatalogFilters','Control','.',props='anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -187.0\noffset_right = 720.0\noffset_bottom = -121.0\nmouse_filter = 0')
    for i,text in enumerate(['全部英雄','卡池','特殊卡池','活动']):
        p='CatalogFilters/Category'+str(i);s.hit('Category'+str(i),'CatalogFilters',(i*180,0,178,65));s.art('Art',p,(0,0,178,65),'category');s.label('Text',p,(0,0,178,61),text,26,1)
    s.label('Empty','.',(150,610,420,50),'暂无英雄',25,1)
    s.node('Header','Control','.',(0,0,720,64),'mouse_filter = 0')
    s.art('Art','Header',(0,0,720,64),'hero_detail.top')
    for name,x,art in [('Diamonds',91,'diamonds'),('Coins',267,'coins')]:
        s.hit(name,'Header',(x,12,153,42));s.art('Art','Header/'+name,(0,0,153,42),'main_ui.'+art);s.label('Value','Header/'+name,(53,0,96,41),'',24,1,'Color(0.77,0.83,0.82,1)')
    s.hit('Help','Header',(10,0,66,74));s.art('Art','Header/Help',(0,0,66,74),'lock')
    s.node('Bottom','Control','.',props='anchor_top = 1.0\nanchor_bottom = 1.0\noffset_top = -108.0\noffset_right = 720.0\nmouse_filter = 0')
    s.art('Art','Bottom',(0,-22,720,130),'hero_detail.bottom')
    for i,text in enumerate(['上阵','培养','图鉴']):
        texture = 'res://assets/runtime/main_ui/nav_2.png' if i==0 else f'res://assets/runtime/hero_management/tab_{i}.png'
        s.node('Tab'+str(i),'TextureButton','Bottom',(i*142,4,142,104),f'texture_normal = {s.ext("Texture2D",texture)}\nignore_texture_size = true\nstretch_mode = 0\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
        s.label('Text','Bottom/Tab'+str(i),(0,74,142,30),text,26,1,'Color(0.78,0.83,0.8,1)')
    s.hit('Back','Bottom',(595,-36,125,104));s.art('Art','Bottom/Back',(0,0,125,104),'hero_detail.back')
    s.save('main_hero_management.tscn')
    card();training_row()


def card():
    s=ManagementScene('main_hero_library_card.gd')
    s.node('Card','Button',rect=(0,0,165,202),props=f'script = {s.script}\ncustom_minimum_size = Vector2(165,202)\nflat = true\nfocus_mode = 0\nmouse_filter = 1\nmouse_default_cursor_shape = 2')
    s.art('Quality','.',(0,0,165,198),'hero_roster.quality_4')
    s.portrait('Portrait','.',(7,20,151,151))
    s.art('Rank','.',(0,4,35,28),'hero_roster.rank')
    s.art('Job','.',(0,34,35,24),'hero_roster.job_1')
    s.art('Element','.',(133,-2,37,37),'hero_roster.element_1')
    s.label('Level','.',(31,3,107,26),'',21,1,'Color(0.13,1,0.13,1)')
    s.label('Name','.',(6,139,151,30),'',22,1,'Color(0.13,1,0.13,1)')
    s.node('PowerArt','Polygon2D','.',props='polygon = PackedVector2Array(0,175,153,175,165,188,153,202,0,202)\ncolor = Color(0,0,0,1)')
    s.art('PowerIcon','.',(1,172,32,32),'hero_detail.power')
    s.label('Power','.',(31,172,128,30),'',27,1)
    for i in range(4):s.node('Star'+str(i),'TextureRect','.',(130,108-i*25,32,32),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.fill('Shade','.','Color(0,0,0,0.48)')
    s.art('Check','.',(100,149,66,54),'check')
    s.save('main_hero_library_card.tscn')


def training_row():
    s=ManagementScene('main_hero_training_row.gd')
    s.node('TrainingRow','Control',rect=(0,0,692,180),props=f'script = {s.script}\ncustom_minimum_size = Vector2(692,180)\nmouse_filter = 2')
    s.art('Art','.',(0,0,692,180),'training_row')
    template=s.ext('PackedScene','res://scenes/town/main_hero_library_card.tscn')
    s.nodes.append(f'[node name="Card" parent="." instance={template}]\noffset_left = 12.0\noffset_top = 11.0\noffset_right = 177.0\noffset_bottom = 213.0\nscale = Vector2(0.78,0.78)')
    s.node('Deployed','Control','.',(158,9,242,31),'mouse_filter = 2')
    s.art('Icon','Deployed',(0,3,25,25),'deployed');s.label('Text','Deployed',(33,0,209,31),'已上阵',22,0,'Color(0.13,1,0.13,1)')
    for i in range(4):
        p='Skill'+str(i);s.hit(p,'.',(169+i*85,69,71,71));s.nodes[-1]+='\nmouse_filter = 1';s.node('Art','TextureRect',p,(0,0,71,71),'expand_mode = 1\nmouse_filter = 2');s.art('Frame',p,(-3,-3,77,77),'hero_detail.skill_frame');s.art('Corner',p,(46,-2,27,26),'hero_detail.skill_level');s.label('Level',p,(46,-2,27,28),'',23,1)
        s.art('Lock',p,(9,9,53,53),'hero_detail.skill_lock');s.nodes[-1]+='\nvisible = false'
    s.node('Portrait','TextureRect','.',(581,35,44,44),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.art('CostArt','.',(567,74,77,29),'count')
    s.node('Cost','RichTextLabel','.',(561,74,90,30),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 21')
    s.hit('Upgrade','.',(550,111,110,42));s.nodes[-1]+='\nmouse_filter = 1';s.art('Art','Upgrade',(0,0,110,42),'upgrade');s.label('Text','Upgrade',(0,0,110,42),'升星',23,1,'Color(1,0.92,0.04,1)')
    s.label('Max','.',(549,97,114,50),'已满星',23,1)
    s.save('main_hero_training_row.tscn')


if __name__=='__main__': main()
