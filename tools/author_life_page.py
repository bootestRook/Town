"""Author fixed life-shop scenes at the project's 750 x 1334 logical viewport."""
from author_building_scenes import Scene

GREEN = 'Color(0.204, 0.804, 0.247, 1)'
WHITE = 'Color(0.953, 0.953, 0.827, 1)'


def art(s, name, parent, rect, asset, patch=False):
    texture = s.ext('Texture2D', f'res://assets/runtime/life_ui/{asset}.png')
    props = f'texture = {texture}\nmouse_filter = 2'
    props += '\npatch_margin_left = 12\npatch_margin_top = 12\npatch_margin_right = 12\npatch_margin_bottom = 12' if patch else '\nexpand_mode = 1'
    s.node(name, 'NinePatchRect' if patch else 'TextureRect', parent, rect, props)


def button(s, name, parent, rect, asset=None, text='', size=26):
    s.node(name, 'Button', parent, rect, 'flat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
    path = name if parent == '.' else parent+'/'+name
    if asset: art(s, 'Art', path, (0,0,rect[2],rect[3]), asset)
    if text: s.label('Text', path, (0,0,rect[2],rect[3]), text, size, 1)


def rich(s, name, parent, rect, size=24):
    s.node(name, 'RichTextLabel', parent, rect, f'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = {size}\ntheme_override_colors/default_color = {WHITE}\ntheme_override_colors/font_outline_color = Color(0.01,0.025,0.03,1)\ntheme_override_constants/outline_size = 3')


def progress(s, name, parent, rect, bg, fill):
    props = f'texture_under = {s.ext("Texture2D", f"res://assets/runtime/life_ui/{bg}.png")}\ntexture_progress = {s.ext("Texture2D", f"res://assets/runtime/life_ui/{fill}.png")}\nnine_patch_stretch = true\nstretch_margin_left = 8\nstretch_margin_right = 8\nstretch_margin_top = 8\nstretch_margin_bottom = 8\nmax_value = 1.0\nstep = 0.001\nmouse_filter = 2'
    s.node(name, 'TextureProgressBar', parent, rect, props)


def overlay(s, name):
    s.node(name, 'Control', '.', (0,0,750,1334), 'visible = false')
    s.node('Shade', 'ColorRect', name, (0,0,750,1334), 'color = Color(0,0,0,0.72)\nmouse_filter = 2')
    button(s, 'Dismiss', name, (0,0,750,1334))


def life():
    s=Scene('life_page.gd')
    s.node('Life','Control',None,(0,0,750,1334),f'script = {s.script}\nclip_contents = true')
    # Reconstructed source textures retain transparent original-size margins.
    s.tex('Room','.',(0,-292,750,1625),'hospital_room')
    s.node('Machine','Sprite2D','.',props='position = Vector2(375, 658)\nhframes = 8\nscale = Vector2(1.05,1.05)')
    s.tex('Curtain','.',(0,54,750,560),'curtain')
    s.node('Seats','HBoxContainer','.',(15,291,720,178),'alignment = 1\ntheme_override_constants/separation = 20\nmouse_filter = 2')
    s.tex('Shelf','.',(4,488,742,208),'shelf')
    art(s,'ProductBadge','.',(32,478,84,42),'badge');s.label('ProductCaption','.',(32,478,84,42),'成品',21,1)
    art(s,'ProductBackground','.',(322,524,102,98),'product_bg')
    button(s,'Product','.',(319,526,112,116))
    s.tex('Icon','Product',(9,4,92,92),'item_20151')
    s.label('Stock','.',(350,591,75,43),'0',28,1,'Color(1,1,1,1)')
    art(s,'PriceBackground','.',(313,628,119,32),'product_price')
    s.label('Price','.',(348,627,80,34),'0',26,1,'Color(1,1,1,1)')
    s.label('Empty','.',(125,561,500,64),'没有商品了,请尽快制作！',27,1,'Color(0.77,0.043,0.043,1)')
    s.node('WorkArea','Control','.',(180,686,390,320),'mouse_filter = 2')
    progress(s,'Production','.',(192,1000,366,26),'progress_bg','progress_blue');s.nodes[-1]+='\nvisible = false'
    s.tex('Desk','.',(0,1100,750,246),'desk')
    art(s,'MaterialBadge','.',(33,1080,104,43),'badge');s.label('MaterialCaption','.',(33,1080,104,43),'原材料',21,1)
    s.tex('Material','.',(325,1136,100,100),'item_20101');s.nodes[-1]=s.nodes[-1].replace('mouse_filter = 2','mouse_filter = 0\nmouse_default_cursor_shape = 6')
    s.label('MaterialCount','.',(325,1210,100,40),'8',29,1,'Color(1,1,1,1)')
    button(s,'AcquireHint','.',(294,1080,162,57),'acquire_hint')
    s.label('Text','AcquireHint',(0,0,162,43),'获得途径',24,1,'Color(0,0,0,1)');s.nodes[-1]+='\ntheme_override_constants/outline_size = 0'
    art(s,'HintBackground','.',(216,1271,320,31),'hint')
    s.label('Hint','.',(213,1270,326,31),'拖动材料至中间的操作台即可开始生产',17,1)
    s.tex('Header','.',(14,99,721,187),'header')
    art(s,'Stats','.',(33,114,683,55),'stats')
    s.label('Name','.',(53,121,76,39),'医院',27)
    s.label('Level','.',(134,121,82,39),'Lv5',28)
    s.label('Bonus','.',(264,121,104,39),'+21%',24,color=GREEN)
    s.label('Reduction','.',(428,121,78,39),'-0S',27,color=GREEN)
    s.label('Capacity','.',(591,121,49,39),'1',27,color=GREEN)
    button(s,'PriceInfo','.',(219,115,146,53))
    button(s,'TimeInfo','.',(374,115,137,53))
    button(s,'SeatInfo','.',(519,115,135,53))
    button(s,'BuySeat','.',(668,118,46,46),'plus')
    s.label('UpgradeInfo','.',(62,182,126,38),'进度条满：',23)
    art(s,'BenefitIcon','.',(176,176,62,46),'seats')
    s.label('Benefit','.',(239,182,238,38),'+1',28,color=GREEN)
    progress(s,'LevelProgress','.',(60,227,446,29),'progress_bg','progress_blue')
    s.button('Upgrade','.',(546,207,146,53),'升级','upgrade',32)
    s.nodes[-1]=s.nodes[-1].replace('Color(0.96, 0.92, 0.76, 1)','Color(1, 0.87, 0.06, 1)')
    art(s,'UpgradeCostBg','.',(554,185,130,29),'cost_bg')
    s.tex('UpgradeCoin','.',(533,176,45,43),'coin')
    s.label('UpgradeCost','.',(577,182,102,34),'2700',25,1,'Color(1,1,1,1)')
    s.node('ProductTip','Control','.',(231,689,288,131),'mouse_filter = 2')
    art(s,'Background','ProductTip',(0,0,288,131),'tip',True)
    art(s,'TitleBackground','ProductTip',(84,6,120,31),'tip_title',True)
    s.label('Title','ProductTip',(5,5,278,32),'纱布绷带',23,1)
    s.label('Recovery','ProductTip',(4,38,280,31),'恢复生命:100%',24,1)
    rich(s,'Price','ProductTip',(0,71,288,30),24)
    rich(s,'Duration','ProductTip',(0,101,288,30),24)
    s.node('Bubble','Control','.',(180,170,390,75),'visible = false\nmouse_filter = 2')
    art(s,'Background','Bubble',(0,0,390,75),'tip',True)
    s.label('Text','Bubble',(10,4,370,65),'',23,1)
    s.tex('Topbar','.',(0,0,750,67),'topbar')
    button(s,'Help','.',(13,-12,64,102),'help')
    s.tex('GoldBar','.',(378,9,174,44),'money_bg')
    art(s,'DiamondBar','.',(568,9,179,44),'diamond_bar')
    s.label('Coins','.',(425,7,114,47),'60k',26,1,'Color(1,1,1,1)')
    s.label('Diamonds','.',(619,7,112,47),'1155',26,1,'Color(1,1,1,1)')
    button(s,'GoldAdd','.',(378,9,174,44))
    button(s,'DiamondAdd','.',(568,9,179,44))
    s.tex('Ghost','.',(0,0,100,100),'item_20101');s.nodes[-1]+='\nvisible = false'
    overlay(s,'SeatPanel')
    art(s,'Panel','SeatPanel',(15,374,720,590),'seat_panel')
    s.label('Title','SeatPanel',(182,417,386,46),'同时治疗人数',28,1)
    for index, y in enumerate([484,588,692,796]):
        name=f'Row{index}'
        s.node(name,'Control','SeatPanel',(96,y,558,111))
        art(s,'Background',f'SeatPanel/{name}',(0,0,558,111),'seat_row')
        s.label('Label',f'SeatPanel/{name}',(156,29,244,50),'等级40' if index==0 else ('激活月卡增加1人' if index==1 else ''),22)
        s.label('State',f'SeatPanel/{name}',(396,28,140,52),'未达成' if index==0 else '已购买',25,1,color=GREEN)
        if index>0: button(s,'Buy',f'SeatPanel/{name}',(409,31,127,57),'buy','激活' if index==1 else '购买',25)
        if index>1:
            art(s,'Diamond',f'SeatPanel/{name}',(182,35,40,36),'diamond')
            s.label('Price',f'SeatPanel/{name}',(228,31,135,49),'0',26,1)
    s.label('DismissHint','SeatPanel',(180,1000,390,46),'点击空白处关闭界面',23,1)
    overlay(s,'ReportPanel')
    art(s,'Panel','ReportPanel',(15,200,720,934),'report_panel')
    s.label('Title','ReportPanel',(100,246,550,51),'经营日报',28,1,'Color(1,0.87,0.15,1)')
    for name,text,y in [('Sales','销售流水',324),('Records','销售记录',470)]:
        art(s,name+'Bg','ReportPanel',(169,y,412,41),'report_subhead')
        s.label(name,'ReportPanel',(169,y,412,41),text,23,1)
    s.tex('Coin','ReportPanel',(269,381,65,60),'coin');s.label('Total','ReportPanel',(339,385,180,52),'0',34,0,color=GREEN)
    s.node('Scroll','ScrollContainer','ReportPanel',(85,521,580,527),'horizontal_scroll_mode = 0')
    rich(s,'Text','ReportPanel/Scroll',(0,0,561,527),21);s.nodes[-1]+='\ncustom_minimum_size = Vector2(561,527)\nfit_content = true\nsize_flags_horizontal = 3'
    art(s,'HintBg','ReportPanel',(129,1070,492,38),'hint')
    s.label('Hint','ReportPanel',(127,1070,496,38),'日报只统计当日信息，每日0点重新统计',18,1)
    s.label('DismissHint','ReportPanel',(180,1155,390,46),'点击空白处关闭界面',23,1)
    overlay(s,'HelpPanel')
    art(s,'Panel','HelpPanel',(15,372,720,590),'seat_panel')
    s.label('Title','HelpPanel',(182,416,386,46),'医院说明',28,1)
    s.label('Description','HelpPanel',(75,541,600,50),'用于回复英雄生命值的建筑',29,1)
    art(s,'Subhead','HelpPanel',(169,647,412,41),'report_subhead')
    s.label('Subtotal','HelpPanel',(169,647,412,41),'当前总加成',25,1)
    for name, x, asset, caption in [('Price',146,'help_price','价格增加'),('Time',395,'help_time','时间减少')]:
        art(s,name+'Card','HelpPanel',(x,709,204,204),asset)
        s.label(name,'HelpPanel',(x+20,820,164,46),'0',33,1,color=GREEN)
        s.label(name+'Caption','HelpPanel',(x+20,867,164,31),caption,21,1)
    s.label('DismissHint','HelpPanel',(180,1174,390,46),'点击空白处关闭界面',23,1)
    acquire(s)
    s.save('life_page.tscn')
    seat()


def acquire(s):
    overlay(s,'AcquirePanel')
    art(s,'Panel','AcquirePanel',(15,194,720,934),'report_panel')
    s.label('Title','AcquirePanel',(170,244,410,50),'获得途径',29,1,'Color(1,0.87,0.15,1)')
    art(s,'Info','AcquirePanel',(89,320,573,188),'acquire_info',True)
    s.tex('Icon','AcquirePanel',(108,337,121,124),'item_20101')
    s.label('Count','AcquirePanel',(108,444,121,43),'0',28,1)
    s.label('Name','AcquirePanel',(246,320,389,36),'',24)
    rich(s,'Description','AcquirePanel',(246,365,387,132),20)
    art(s,'Subhead','AcquirePanel',(169,522,412,41),'report_subhead')
    s.label('Subtitle','AcquirePanel',(169,522,412,41),'可通过以下方式获取',23,1)
    for index,caption in enumerate(['交易所收购','拾取怪物的掉落','领取挂机奖励']):
        name=f'Way{index}'; y=583+index*118
        button(s,name,'AcquirePanel',(83,y,583,106),'acquire_row')
        if index==2: s.nodes[-2]+='\ndisabled = true'
        art(s,'Icon','AcquirePanel/'+name,(47,-6,118,123),'acquire_idle' if index==2 else 'acquire_exchange')
        s.label('Caption','AcquirePanel/'+name,(186,20,235,64),caption,23)
        if index==2:
            art(s,'Lock','AcquirePanel/'+name,(439,12,81,82),'locked')
        else:
            art(s,'Go','AcquirePanel/'+name,(414,23,135,62),'buy')
            s.label('GoText','AcquirePanel/'+name,(414,23,135,62),'前往',27,1,'Color(1,0.87,0.15,1)')
    s.label('DismissHint','AcquirePanel',(180,1230,390,46),'点击空白处关闭界面',23,1)


def seat():
    s=Scene()
    s.node('Seat','Control',None,props='custom_minimum_size = Vector2(174,178)\nmouse_filter = 2')
    s.node('Crop','Control','.',(0,0,174,152),'clip_contents = true\nmouse_filter = 2')
    s.node('Hero','TextureRect','Crop',(0,0,174,214),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    progress(s,'Progress','.',(39,139,96,38),'timer_bg','timer_green')
    s.label('Time','.',(35,139,104,38),'10S',30,1)
    s.save('service_seat.tscn')


if __name__ == '__main__':
    life()
