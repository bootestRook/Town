"""Author fixed Godot building UI scenes. Runtime never constructs this skeleton."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


class Scene:
    def __init__(self, script=''):
        self.resources, self.nodes = [], []
        self.script = self.ext('Script', 'res://src/features/town/presentation/' + script) if script else None

    def ext(self, kind, path):
        key = str(len(self.resources)+1)
        self.resources.append(f'[ext_resource type="{kind}" path="{path}" id="{key}"]')
        return f'ExtResource("{key}")'

    def node(self, name, kind, parent=None, rect=None, props=''):
        head = f'[node name="{name}" type="{kind}"' + (f' parent="{parent}"' if parent is not None else '') + ']'
        lines = [head]
        if rect:
            x,y,w,h = rect
            lines += [f'offset_left = {float(x)}',f'offset_top = {float(y)}',f'offset_right = {float(x+w)}',f'offset_bottom = {float(y+h)}']
        if props: lines.append(props)
        self.nodes.append('\n'.join(lines))

    def tex(self, name, parent, rect, asset):
        self.node(name,'TextureRect',parent,rect,f'texture = {self.ext("Texture2D", "res://assets/runtime/operations/"+asset+".png")}\nexpand_mode = 1\nmouse_filter = 2')

    def label(self, name, parent, rect, text='', size=25, align=0, color='Color(0.96, 0.92, 0.76, 1)'):
        self.node(name,'Label',parent,rect,f'text = {json.dumps(text,ensure_ascii=False)}\ntheme_override_font_sizes/font_size = {size}\ntheme_override_colors/font_color = {color}\ntheme_override_colors/font_outline_color = Color(0.015, 0.03, 0.04, 1)\ntheme_override_constants/outline_size = 4\nhorizontal_alignment = {align}\nvertical_alignment = 1\nmouse_filter = 2')

    def button(self,name,parent,rect,text,asset='confirm',size=27):
        self.node(name,'Button',parent,rect,'flat = true\nmouse_default_cursor_shape = 2\nfocus_mode = 0')
        full = name if parent == '.' else parent+'/'+name
        self.tex('Art',full,(0,0,rect[2],rect[3]),asset)
        self.label('Text',full,(0,0,rect[2],rect[3]),text,size,1)

    def save(self,name):
        p = ROOT/'scenes/town'/name
        p.parent.mkdir(parents=True,exist_ok=True)
        resources = sorted(self.resources, key=lambda r:r.startswith('[sub_resource'))
        p.write_text('[gd_scene format=3]\n\n'+'\n'.join(resources)+'\n\n'+'\n\n'.join(self.nodes)+'\n',encoding='utf8',newline='\n')


def shop():
    s=Scene('shop_page.gd');s.node('Shop','Control',None,(0,0,750,1334),f'script = {s.script}')
    s.tex('Backdrop','.',(0,50,750,520),'exchange_top');s.tex('Body','.',(0,496,750,838),'exchange_body')
    s.tex('Banner','.',(15,81,720,201),'building_banner')
    s.node('Building','TextureRect','.',(73,74,195,166),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Title','.',(286,104,414,58),'交易所 1级',34,1,'Color(1,0.92,0.1,1)')
    s.label('Subtitle','.',(286,182,414,66),'英雄与玩家交易的建筑物',23,1)
    s.tex('Condition','.',(35,300,680,113),'condition_banner')
    s.tex('Chain1','.',(84,257,28,92),'chain');s.tex('Chain2','.',(638,257,28,92),'chain')
    s.label('ConditionText','.',(113,330,435,49),'',25,1)
    s.button('Upgrade','.',(553,333,134,55),'升级','upgrade',25)
    s.tex('Section','.',(178,466,394,70),'exchange_title');s.label('SectionText','.',(190,478,370,44),'材料',28,1)
    s.button('Tier','.',(22,549,145,58),'一阶 ▾','tier_menu',26)
    s.node('Scroll','ScrollContainer','.',(22,628,706,589),'horizontal_scroll_mode = 0')
    s.node('Grid','GridContainer','Scroll',props='layout_mode = 2\ncolumns = 4\ntheme_override_constants/h_separation = 12\ntheme_override_constants/v_separation = 12')
    s.label('Empty','.',(75,790,600,65),'暂无待售装备',30,1)
    s.node('Heroes','ScrollContainer','.',(22,570,706,635),'horizontal_scroll_mode = 0\nvisible = false')
    s.node('Rows','VBoxContainer','Heroes',props='layout_mode = 2\nsize_flags_horizontal = 3\ntheme_override_constants/separation = 16')
    s.tex('Bottom','.',(0,1210,750,124),'exchange_bottom')
    s.button('Tab1','.',(4,1230,144,102),'预购','tab_orders',26)
    s.button('Tab2','.',(151,1230,144,102),'英雄','tab_heroes',26)
    s.button('Tab3','.',(300,1230,144,102),'出售','tab_heroes',26)
    s.save('shop_page.tscn')


def shell():
    s=Scene('building_ui.gd');font=s.ext('FontFile','res://assets/runtime/operations/font.ttf')
    s.resources.append('[sub_resource type="StyleBoxFlat" id="Progress_bg"]\nbg_color = Color(0.035,0.095,0.11,1)\nborder_width_left = 2\nborder_width_top = 2\nborder_width_right = 2\nborder_width_bottom = 2\nborder_color = Color(0.01,0.02,0.025,1)')
    s.resources.append('[sub_resource type="StyleBoxFlat" id="Progress_fill"]\nbg_color = Color(0.19,0.69,0.48,1)')
    s.resources.append(f'[sub_resource type="Theme" id="Theme_main"]\ndefault_font = {font}\ndefault_font_size = 24\nProgressBar/styles/background = SubResource("Progress_bg")\nProgressBar/styles/fill = SubResource("Progress_fill")')
    s.node('BuildingUI','Control',None,props=f'visible = false\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = {s.script}\ntheme = SubResource("Theme_main")')
    s.node('Backdrop','ColorRect','.',props='anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ncolor = Color(0.025,0.05,0.06,1)')
    s.node('Stage','Control','.',(0,0,750,1334),'mouse_filter = 2')
    for name,scene in [('Life','life_page.tscn'),('Shop','shop_page.tscn'),('Revival','revival_page.tscn'),('Camp','hero_camp_page.tscn'),('Horn','battle_horn_page.tscn'),('EquipmentShop','equipment_shop_page.tscn')]:
        resource=s.ext('PackedScene','res://scenes/town/'+scene)
        s.nodes.append(f'[node name="{name}" parent="Stage" instance={resource}]')
    s.tex('Topbar','Stage',(0,0,750,67),'topbar');s.tex('MoneyBg','Stage',(464,10,218,49),'money_bg');s.tex('Coin','Stage',(468,6,51,51),'coin')
    s.label('Coins','Stage',(519,7,157,48),'60000',30,1)
    s.button('Back','Stage',(633,1211,117,110),'','back')
    s.button('Report','Stage',(652,987,87,87),'','report');s.label('ReportLabel','Stage',(653,1067,82,40),'日报',24,1)
    s.node('Notice','Label','Stage',(105,938,540,74),'visible = false\nhorizontal_alignment = 1\nvertical_alignment = 1\nautowrap_mode = 2\ntheme_override_font_sizes/font_size = 27\ntheme_override_colors/font_color = Color(1,0.84,0.35,1)\ntheme_override_constants/outline_size = 10\nmouse_filter = 2')
    s.nodes[-1] += '\nz_index = 10'
    s.node('Modal','Control','Stage',(0,0,750,1334),'visible = false\nz_index = 5')
    s.node('Shade','ColorRect','Stage/Modal',(0,0,750,1334),'color = Color(0,0,0,0.72)')
    s.tex('Panel','Stage/Modal',(23,290,704,766),'dialog')
    s.label('Title','Stage/Modal',(83,310,584,62),'预购',34,1)
    s.node('Icon','TextureRect','Stage/Modal',(299,404,152,152),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Detail','Stage/Modal',(80,565,590,106),'',25,1)
    s.button('Minus','Stage/Modal',(143,701,92,69),'−')
    s.label('Count','Stage/Modal',(262,697,226,77),'0',38,1)
    s.button('Plus','Stage/Modal',(515,701,92,69),'+')
    s.button('Reset','Stage/Modal',(143,791,180,62),'清空',size=25)
    s.button('Ten','Stage/Modal',(427,791,180,62),'+10',size=25)
    s.button('Cancel','Stage/Modal',(110,928,226,76),'取消')
    s.button('Confirm','Stage/Modal',(414,928,226,76),'确定')
    s.node('ReportPanel','Control','Stage',(0,0,750,1334),'visible = false')
    s.node('Shade','ColorRect','Stage/ReportPanel',(0,0,750,1334),'color = Color(0,0,0,0.76)')
    s.tex('Panel','Stage/ReportPanel',(23,163,704,942),'dialog');s.label('Title','Stage/ReportPanel',(80,182,590,64),'经营日报',34,1)
    s.node('Scroll','ScrollContainer','Stage/ReportPanel',(68,272,614,681),'horizontal_scroll_mode = 0')
    s.node('Text','Label','Stage/ReportPanel/Scroll',props='custom_minimum_size = Vector2(590, 0)\nsize_flags_horizontal = 3\nautowrap_mode = 2\ntheme_override_font_sizes/font_size = 23\nmouse_filter = 2')
    s.button('Close','Stage/ReportPanel',(259,985,232,78),'关闭')
    s.save('building_ui.tscn')


def cards():
    s=Scene();s.node('Item','Button',None,props='custom_minimum_size = Vector2(166, 208)\nflat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
    s.tex('Background','.',(0,0,166,208),'item_cell');s.tex('Quality','.',(18,17,130,121),'quality_1')
    s.node('Icon','TextureRect','.',(31,26,104,104),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.tex('Tier','.',(17,15,52,39),'tier');s.label('Name','.',(6,142,154,34),'',22,1);s.label('Count','.',(4,177,158,28),'',18,1)
    s.save('item_card.tscn')
    s=Scene();s.node('Recipe','Button',None,props='custom_minimum_size = Vector2(342, 268)\nflat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
    s.tex('Background','.',(0,0,342,268),'item_cell');s.tex('Quality','.',(21,18,120,111),'quality_2')
    s.node('Icon','TextureRect','.',(29,21,107,107),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('Name','.',(148,24,181,55),'',25,1);s.label('Power','.',(148,81,181,48),'',22,1)
    s.label('Cost','.',(15,137,314,89),'',21,1);s.label('Action','.',(24,228,294,32),'打造',25,1,'Color(1,0.83,0.22,1)');s.save('recipe_card.tscn')
    s=Scene();s.node('Hero','Control',None,props='custom_minimum_size = Vector2(698, 260)')
    s.tex('Background','.',(0,0,698,260),'shelf')
    s.node('Portrait','Sprite2D','.',props='position = Vector2(85,85)\nhframes = 8\nscale = Vector2(0.9,0.9)')
    s.label('Name','.',(156,10,347,42),'',28);s.label('State','.',(156,51,495,62),'',21)
    s.label('Bag','.',(23,125,646,112),'',21);s.button('Summon','.',(525,17,148,57),'召唤',size=23);s.save('hero_row.tscn')



if __name__ == '__main__':
    from author_life_page import life
    life();shop();shell();cards()
