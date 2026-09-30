"""Fixed regional density modal, source gate, row and item scenes."""
from author_building_scenes import Scene,ROOT
from author_equipment_shop_scene import icon,hit
from author_battle_horn_scene import art
from author_equipment_theme import theme

def image(s,name,parent,rect,key):art(s,name,parent,rect,'region/'+key)
def main():
 s=Scene('town_region_page.gd');s.node('RegionUI','Control',None,props=f'script = {s.script}\nvisible = false\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ntheme = {theme(s)}')
 s.node('Dismiss','Button','.',props='anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nflat = true\nfocus_mode = 0')
 s.node('Dim','ColorRect','Dismiss',props='anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ncolor = Color(0,0,0,0.72)\nmouse_filter = 2')
 s.node('Stage','Control','.',(0,0,750,1334),'mouse_filter = 2')
 s.node('Panel','Control','Stage',(15,70,720,1145),'mouse_filter = 0');image(s,'Art','Stage/Panel',(0,0,720,1145),'modal')
 s.label('Title','Stage',(215,113,320,42),'兽人密林',30,1,'Color(1,0.93,0.05,1)')
 hit(s,'Help','Stage',(95,84,87,87));image(s,'Art','Stage/Help',(0,0,87,87),'help')
 image(s,'Shelf','Stage',(61,197,628,135),'shelf');image(s,'DropTitle','Stage',(265,181,230,34),'drop_title')
 s.label('DropLabel','Stage',(243,179,270,37),'本区域会掉落以下材料',21,1)
 s.node('Drops','ScrollContainer','Stage',(70,219,610,104),'vertical_scroll_mode = 0\nhorizontal_scroll_mode = 3')
 s.node('Items','HBoxContainer','Stage/Drops',props='layout_mode = 2\ntheme_override_constants/separation = 10')
 image(s,'Divider','Stage',(210,382,330,41),'divider')
 s.node('Rows','VBoxContainer','Stage',(83,427,584,732),'theme_override_constants/separation = 12')
 s.label('Hint','Stage',(155,1254,440,44),'点击空白处关闭界面',24,1,'Color(0.75,0.85,0.85,1)')
 dialog=s.ext('PackedScene','res://scenes/town/equipment_dialog.tscn');s.nodes.append(f'[node name="Dialog" parent="Stage" instance={dialog}]\nvisible = false')
 s.save('region_page.tscn')
 p=ROOT/'scenes/town/region_page.tscn';p.write_text('; THESIS: Source regional activation controls real monster density.\n; OWN-WORLD: Original inked orange frame, teal panels, Chinese cream type.\n; STORY: Inspect drops and species, activate an unlocked density, hunt its population.\n; FIRST VIEWPORT: Dim town, source title and drops, three density rows, blank dismissal.\n; FORM: Source-pinned screenshots and prefab; expand incumbent world.\n; FINISH: unreviewed and undocumented is unfinished; finish review, verdict, DESIGN.md and provenance required.\n'+p.read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
 s=Scene('town_region_row.gd');s.node('Density','Control',None,props=f'script = {s.script}\ncustom_minimum_size = Vector2(584,236)')
 image(s,'Background','.',(0,0,584,213),'row');image(s,'Active','.',(0,0,584,213),'active')
 s.node('Monsters','Control','.',(15,43,554,125),'mouse_filter = 2')
 s.node('Shade','ColorRect','.',(10,9,564,192),'color = Color(0,0,0,0.5)\nmouse_filter = 2')
 hit(s,'Activate','.',(191,174,205,67));image(s,'Art','Activate',(0,0,205,67),'activate')
 s.label('Level','Activate',(20,-3,165,27),'Lv.1',23,1,'Color(1,1,1,1)');s.label('Text','Activate',(20,20,165,41),'激活',27,1,'Color(1,0.93,0.05,1)')
 image(s,'Activated','.',(185,192,221,40),'activated');s.label('Status','.',(109,194,367,43),'Lv.2 激活中...',28,1,'Color(0.13,0.87,0.12,1)')
 s.label('Locked','.',(15,73,554,68),'通过地下城1-30后解锁',22,1,'Color(0.95,0.27,0.07,1)')
 s.save('region_row.tscn')
 s=Scene();s.node('Monster','Control',None,(0,0,105,126),'mouse_filter = 2');icon(s,'Portrait','.',(-20,-28,144,144));image(s,'Elite','.',(0,92,37,37),'elite');s.label('Count','.',(39,97,66,37),'x3',30,2);s.save('region_monster.tscn')
 s=Scene();s.node('Drop','Button',None,props='custom_minimum_size = Vector2(94,94)\nflat = true\nfocus_mode = 0');icon(s,'Quality','.',(0,0,94,94));icon(s,'Icon','.',(3,3,88,88));icon(s,'Tier','.',(0,0,34,23));s.save('region_drop.tscn')
 s=Scene();s.node('Gate','Node2D');s.node('Art','Sprite2D','.');s.save('region_gate.tscn')
if __name__=='__main__':main()
