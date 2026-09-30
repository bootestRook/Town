"""Editable 720-point source recruitment drawer and its fixed modal states."""
from author_main_ui_scenes import MainScene

class RecruitScene(MainScene):
    def art(self,name,parent,rect,asset):
        path='res://assets/runtime/'+(asset if '/' in asset else 'recruitment/'+asset)+'.png'
        self.node(name,'TextureRect',parent,rect,f'texture = {self.ext("Texture2D",path)}\nexpand_mode = 1\nmouse_filter = 2')
    def region(self,name,parent,rect,asset,region):
        texture=self.ext('Texture2D','res://assets/runtime/recruitment/'+asset+'.png')
        resource='Region'+str(len(self.resources))
        self.resources.append(f'[sub_resource type="AtlasTexture" id="{resource}"]\natlas = {texture}\nregion = Rect2({",".join(map(str,region))})')
        self.node(name,'TextureRect',parent,rect,f'texture = SubResource("{resource}")\nexpand_mode = 1\nmouse_filter = 2')
    def hit(self,name,parent,rect):
        self.node(name,'Button',parent,rect,'flat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
    def action(self,name,parent,rect,text,asset='purple',size=28):
        self.hit(name,parent,rect);p=name if parent=='.' else parent+'/'+name
        self.art('Art',p,(0,0,rect[2],rect[3]),asset);self.label('Text',p,(8,0,rect[2]-16,rect[3]),text,size,1)
    def portrait(self,name,parent,rect):
        self.node(name,'TextureRect',parent,rect,f'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2\nscript = {self.ext("Script","res://src/features/town/presentation/hero_idle_portrait.gd")}')
    def progress(self,name,parent,rect,empty,full):
        def texture(asset):return self.ext('Texture2D','res://assets/runtime/recruitment/'+asset+'.png')
        self.node(name,'TextureProgressBar',parent,rect,f'texture_under = {texture(empty)}\ntexture_progress = {texture(full)}\nnine_patch_stretch = true\nmouse_filter = 2')
    def wrap(self,name,parent,rect,text,size=24,align=0):
        self.label(name,parent,rect,text,size,align);self.nodes[-1]+='\nautowrap_mode = 2'
    def privilege_banner(self,name,parent,rect):
        # Native UI clipping preserves the supplied artwork without showing its old scene.
        self.node(name,'Control',parent,rect,'mouse_filter = 2')
        p=parent+'/'+name
        outline=[(256,1182),(270,1168),(545,1168),(550,1160),(563,1148),(582,1140),(606,1138),(630,1141),(650,1150),(670,1164),(683,1180),(687,1196),(683,1210),(672,1225),(655,1236),(635,1243),(612,1244),(586,1240),(563,1229),(560,1244),(554,1247),(560,1255),(555,1262),(561,1269),(561,1287),(256,1287)]
        points=','.join(str(round(v,3)) for x,y in outline for v in ((x-250)*rect[2]/440,(y-1134)*rect[3]/164))
        self.node('Outline','Polygon2D',p,props=f'polygon = PackedVector2Array({points})\nclip_children = 1\nantialiased = true')
        self.region('Art',p+'/Outline',(0,0,rect[2],rect[3]),'refresh_reference',(250,1134,440,164))

def main():
    s=RecruitScene('main_recruitment.gd')
    s.node('Recruitment','Control',rect=(0,0,720,708),props=f'script = {s.script}\nmouse_filter = 2')
    s.node('Body','Control','.',(0,0,720,608),'mouse_filter = 0\nclip_contents = true')
    s.art('Background','Body',(0,0,720,714),'background')
    s.art('Captain','.',(0,-289,605,289),'captain')
    s.wrap('Speech','Captain',(220,173,364,95),'',24,1);s.nodes[-1]=s.nodes[-1].replace('outline_size = 4','outline_size = 0').replace('Color(0.96, 0.92, 0.76, 1)','Color(0.04,0.04,0.02,1)')
    s.art('XpFrame','Body',(0,12,632,102),'xp_frame')
    s.progress('Xp','Body',(83,40,380,34),'xp_fill','xp_empty')
    s.label('XpText','Body',(115,32,334,50),'',25,1)
    s.hit('Illustration','Body',(4,5,116,102));s.art('Art','Body/Illustration',(0,0,116,102),'level');s.label('Text','Body/Illustration',(6,60,104,36),'',25,1,'Color(1,0.92,0,1)')
    s.hit('Probability','Body',(484,32,48,49));s.art('Art','Body/Probability',(0,0,48,49),'info')
    s.hit('Tickets','Body',(586,93,134,46));s.art('Bg','Body/Tickets',(0,0,134,46),'main_ui/energy');s.art('Art','Body/Tickets',(1,-5,43,45),'ticket');s.label('Value','Body/Tickets',(49,0,78,41),'',28,1)
    s.art('Timer','Body',(76,140,542,50),'timer');s.node('Countdown','RichTextLabel','Body',(98,151,521,43),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 23')
    s.hit('Help','Body',(28,131,56,57));s.art('Art','Body/Help',(0,0,56,57),'help')
    s.hit('Wish','Body',(606,150,88,92));s.region('Art','Body/Wish',(0,0,88,88),'reference',(695,919,104,102));s.label('Text','Body/Wish',(-2,64,92,30),'未激活',21,1,'Color(1,0.07,0.04,1)')
    for i,x in enumerate([48,259,470]):
        p='Body/Hero'+str(i);s.hit('Hero'+str(i),'Body',(x,223,204,250));s.portrait('Portrait',p,(-9,-11,225,225))
        s.label('Chance',p,(-5,165,214,36),'',20,1)
        s.art('Element',p,(-1,202,43,43),'hero_roster/element_1');s.label('Name',p,(42,203,170,43),'',29,0)
        s.art('Check',p,(67,-50,66,75),'check')
    s.action('Recruit','Body',(214,504,292,93),'招募','finish',33);s.nodes[-1]=s.nodes[-1].replace('Color(0.96, 0.92, 0.76, 1)','Color(1,0.9,0,1)')
    s.art('Cost','Body/Recruit',(63,-4,171,33),'cost');s.art('Icon','Body/Recruit/Cost',(0,-12,47,47),'ticket')
    s.node('Value','RichTextLabel','Body/Recruit/Cost',(46,-2,118,34),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 26')
    s.action('Refresh','Body',(541,522,149,55),'刷新英雄','refresh',22)
    s.action('Finish','Body',(381,508,292,93),'换一批','recruit',33)
    s.node('Dragon','Control','.',(0,0,720,608),'visible = false\nmouse_filter = 0')
    s.art('Bg','Dragon',(0,0,720,714),'background');s.art('Lock','Dragon',(325,258,70,70),'hero_management/lock')
    s.label('Locked','Dragon',(160,349,400,52),'未解锁',28,1)
    s.hit('DragonInfo','Dragon',(260,219,200,194))
    s.node('Bottom','Control','.',(0,608,720,100),'mouse_filter = 0')
    s.art('Bg','Bottom',(0,-16,720,116),'main_ui/bottom')
    for i,label in enumerate(['英雄','龙魂技能']):
        s.action('Tab'+str(i),'Bottom',(4+i*144,0,141,103),'','main_ui/nav_3' if i==0 else 'tab_dragon')
        s.label('Text2','Bottom/Tab'+str(i),(0,72,141,30),label,23,1)
        if i==1:s.region('Reference','Bottom/Tab1',(0,0,141,103),'reference',(171,1438,159,115))
    s.action('Back','.',(623,-48,97,90),'','hero_detail/back')
    s.node('Strike','ColorRect','Body/Recruit/Cost',(46,15,52,2),'color = Color(0.93,0.12,0.08,1)\nmouse_filter = 2\nvisible = false')
    s.save('main_recruitment.tscn')
    overlay()

def overlay():
    s=RecruitScene('main_recruitment_overlay.gd')
    for name,radius in [('WishFrame',16),('WishStatus',20)]:
        s.resources.append(f'[sub_resource type="StyleBoxFlat" id="{name}"]\nbg_color = Color(0.046,0.112,0.14,1)\nborder_width_left = 3\nborder_width_top = 3\nborder_width_right = 3\nborder_width_bottom = 3\nborder_color = Color(0.005,0.016,0.021,1)\ncorner_radius_top_left = {radius}\ncorner_radius_top_right = {radius}\ncorner_radius_bottom_left = {radius}\ncorner_radius_bottom_right = {radius}')
    s.resources.append(f'[sub_resource type="FontVariation" id="ResultBold"]\nbase_font = {s.ext("FontFile","res://assets/runtime/operations/font.ttf")}\nvariation_embolden = 0.22')
    s.node('RecruitOverlay','Control',rect=(0,0,720,1280),props=f'script = {s.script}\nmouse_filter = 0')
    s.hit('Shade','.',(0,0,720,1280));s.fill('Tint','Shade','Color(0,0,0,0.76)')
    s.node('Panel','Control','.',(20,365,680,530),'mouse_filter = 0')
    # Nine-slice protects source jagged corners and title at every modal height.
    s.node('Frame','NinePatchRect','Panel',(0,0,680,530),f'texture = {s.ext("Texture2D","res://assets/runtime/operations/dialog.png")}\npatch_margin_left = 80\npatch_margin_top = 128\npatch_margin_right = 80\npatch_margin_bottom = 65\nmouse_filter = 2')
    s.label('Title','Panel',(161,37,358,50),'',29,1,'Color(1,0.9,0.02,1)')
    for page in ['Help','Refresh','Finish','Purchase','Wish','Probability','Dragon','Privilege']:
        s.node(page,'Control','Panel',(0,0,680,530),'visible = false\nmouse_filter = 2')
    s.node('Scroll','ScrollContainer','Panel/Help',(89,130,501,345),'horizontal_scroll_mode = 0')
    s.node('Text','Label','Panel/Help/Scroll',props='custom_minimum_size = Vector2(475,0)\nsize_flags_horizontal = 3\nautowrap_mode = 2\ntheme_override_font_sizes/font_size = 24\nmouse_filter = 2')
    s.wrap('Text','Panel/Refresh',(87,169,506,102),'刷新后，将为您重新更换三名英雄',26,1)
    s.art('Divider','Panel/Refresh',(109,340,460,40),'divider')
    s.label('Count','Panel/Refresh',(117,356,202,39),'',20,1)
    s.action('Free','Panel/Refresh',(91,397,200,68),'免费刷新','purple',28);s.art('Video','Panel/Refresh/Free',(-8,-14,44,44),'video')
    s.action('Paid','Panel/Refresh',(389,397,200,68),'','orange');s.art('Icon','Panel/Refresh/Paid',(55,14,43,40),'main_ui/diamond_icon');s.label('Cost','Panel/Refresh/Paid',(105,8,70,50),'50',29,0,'Color(1,0.91,0,1)')
    s.hit('Privilege','Panel/Refresh',(193,550,380,139));s.privilege_banner('Banner','Panel/Refresh/Privilege',(0,0,380,139))
    s.wrap('Text','Panel/Finish',(89,155,502,112),'结束后将会更换三名新的英雄,当前未招募的英雄将会离开,确定要结束本次招募吗?',25)
    s.hit('Remember','Panel/Finish',(95,291,460,66));s.region('Box','Panel/Finish/Remember',(0,0,67,62),'confirm_reference',(144,848,78,72));s.art('Check','Panel/Finish/Remember',(9,5,44,44),'hero_management/check');s.label('Text','Panel/Finish/Remember',(77,0,373,59),'今日不再提醒',26)
    s.action('Cancel','Panel/Finish',(89,395,211,68),'取消');s.action('Accept','Panel/Finish',(382,395,211,68),'确定','orange')
    s.art('ItemFrame','Panel/Purchase',(75,112,112,112),'hero_roster/quality_5');s.art('Item','Panel/Purchase',(75,112,112,112),'ticket');s.label('Name','Panel/Purchase',(202,110,389,42),'英雄招募卷轴',24)
    s.wrap('Desc','Panel/Purchase',(202,155,389,90),'用于招募英雄,可通过挑战BOSS、地下城等渠道获得。',23)
    s.label('QuantityTitle','Panel/Purchase',(222,268,235,44),'购买数量',24,1)
    s.action('Minus','Panel/Purchase',(142,331,61,61),'','minus',36);s.action('Plus','Panel/Purchase',(477,331,61,61),'','plus',36)
    s.art('CountBg','Panel/Purchase',(232,337,216,44),'cost');s.label('Count','Panel/Purchase',(232,326,216,61),'1',31,1,'Color(0.2,0.85,0.2,1)')
    for name,x,text in [('Reset',93,'重置'),('Ten',270,'+10'),('Hundred',447,'+100')]:s.action(name,'Panel/Purchase',(x,451,138,50),text,'refresh',27)
    s.label('CostTitle','Panel/Purchase',(208,549,98,43),'消耗:',24,1);s.art('Diamond','Panel/Purchase',(324,553,43,39),'main_ui/diamond_icon');s.label('Cost','Panel/Purchase',(381,549,155,43),'100',27)
    s.label('Limit','Panel/Purchase',(76,634,147,50),'限购：∞',23);s.action('Buy','Panel/Purchase',(240,616,200,68),'购买','orange',30)
    s.wrap('Text','Panel/Wish',(81,119,518,75),'勾选的心愿英雄，将会提升出现概率!',24,1)
    s.hit('Card','Panel/Wish',(71,206,177,212));s.node('Outer','Panel','Panel/Wish/Card',(0,0,177,198),'theme_override_styles/panel = SubResource("WishFrame")\nmouse_filter = 2');s.art('Frame','Panel/Wish/Card',(25,14,124,155),'hero_roster/quality_5');s.portrait('Portrait','Panel/Wish/Card',(28,21,118,145));s.label('Name','Panel/Wish/Card',(43,16,88,25),'',18,1,'Color(0.2,0.86,0.25,1)')
    s.art('Job','Panel/Wish/Card',(28,20,27,26),'hero_roster/job_1');s.art('Element','Panel/Wish/Card',(123,16,27,27),'hero_roster/element_3')
    for i in range(4):s.node('Star'+str(i),'TextureRect','Panel/Wish/Card',(30+i*29,140,30,30),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.node('StatusFrame','Panel','Panel/Wish/Card',(26,176,139,37),'theme_override_styles/panel = SubResource("WishStatus")\nmouse_filter = 2');s.label('Status','Panel/Wish/Card',(22,176,147,37),'获得后解锁',22,1,'Color(1,0.08,0.04,1)');s.art('Check','Panel/Wish/Card',(122,126,48,48),'hero_management/check')
    s.wrap('Text','Panel/Probability',(80,132,520,336),'',25,1)
    s.wrap('Text','Panel/Dragon',(90,175,500,190),'龙魂技能未解锁',27,1)
    s.privilege_banner('Banner','Panel/Privilege',(151,140,380,139))
    s.wrap('Text','Panel/Privilege',(80,319,520,136),'免广告特权\n每日赠送英雄招募卷轴×10',27,1)
    s.label('CloseTip','.',(110,1105,500,50),'点击空白处关闭界面',23,1,'Color(0.75,0.83,0.84,1)')
    s.node('Animation','Control','.',(0,250,720,730),'visible = false\nmouse_filter = 2')
    s.art('Platform','Animation',(-22,550,763,214),'platform')
    for i,x in enumerate([0,210,420]):
        s.node('Door'+str(i),'Control','Animation',(x,220,300,440),'mouse_filter = 2');p='Animation/Door'+str(i)
        s.art('House',p,(-72,-53,444,461),'house');s.art('Glow',p,(-15,55,285,325),'glow')
        s.art('Column',p,(72,-203,113,487),'column_4_0');s.portrait('Portrait',p,(29,105,190,190))
    for i,x in enumerate([36,248,465]):s.art('Beam'+str(i),'Animation',(x,-285,230,840),'beam')
    s.node('Result','Control','.',(0,430,720,460),'visible = false\nmouse_filter = 0')
    s.art('Rays','Result',(117,-248,486,480),'rays');s.node('Base','ColorRect','Result',(0,12,720,450),'color = Color(0.036,0.13,0.16,1)\nmouse_filter = 2');s.art('Body','Result',(0,105,720,313),'result_body')
    s.node('Ribbon','TextureRect','Result',(-124,-131,968,281),'expand_mode = 1\nmouse_filter = 2')
    s.label('Title','Result',(175,-9,370,84),'招募成功',52,1,'Color(1,0.91,0,1)');s.nodes[-1]=s.nodes[-1].replace('outline_size = 4','outline_size = 7').replace('Color(0.015, 0.03, 0.04, 1)','Color(0,0,0,1)');s.nodes[-1]+='\ntheme_override_fonts/font = SubResource("ResultBold")'
    s.portrait('Portrait','Result',(84,126,221,257));s.label('Name','Result',(358,129,234,46),'',29,1)
    s.art('Job','Result',(359,180,75,75),'job_1');s.art('Element','Result',(457,180,75,75),'hero_roster/element_1')
    for i in range(4):s.node('Star'+str(i),'TextureRect','Result',(378+i*50,265,50,50),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.progress('Progress','Result',(337,336,250,29),'bar_empty','bar_fill');s.art('Fragment','Result',(291,319,60,63),'fragment')
    s.label('Value','Result',(340,325,244,47),'',25,1);s.label('Add','Result',(590,325,113,47),'',27,0,'Color(0.17,0.88,0.18,1)')
    s.label('New','Result',(329,327,278,52),'获得新英雄',28,1,'Color(0.17,0.88,0.18,1)')
    s.save('main_recruitment_overlay.tscn')

if __name__=='__main__':main()
