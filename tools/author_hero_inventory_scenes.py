"""Fixed private bag cells and source equipment detail overlay."""
from author_hero_detail_scene import DetailScene


class InventoryScene(DetailScene):
    def art(self,name,parent,rect,asset):
        if asset=='panel':
            x,y,w,h=rect
            rect=(x-19*w/578,y-19*h/424,w*616/578,h*462/424)
        self.node(name,'TextureRect',parent,rect,f'texture = {self.ext("Texture2D","res://assets/runtime/hero_inventory/"+asset+".png")}\nexpand_mode = 1\nmouse_filter = 2')


def main():
    s=InventoryScene('main_hero_bag.gd')
    s.node('BagPage','Control',rect=(0,0,720,458),props=f'script = {s.script}\nmouse_filter = 2')
    s.resources.append('[sub_resource type="StyleBoxFlat" id="BagBody"]\nbg_color = Color(0.05,0.12,0.15,1)\nborder_color = Color(0.017,0.05,0.06,1)\nborder_width_left = 4\nborder_width_right = 4\nborder_width_top = 4\nborder_width_bottom = 4\ncorner_radius_top_left = 18\ncorner_radius_top_right = 18\ncorner_radius_bottom_left = 18\ncorner_radius_bottom_right = 18')
    s.node('Body','Panel','.',props='anchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 4.0\noffset_right = -4.0\ntheme_override_styles/panel = SubResource("BagBody")\nmouse_filter = 2')
    s.node('Scroll','ScrollContainer','.',props='anchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 10.0\noffset_top = 10.0\noffset_right = -10.0\noffset_bottom = -7.0\nhorizontal_scroll_mode = 0\nvertical_scroll_mode = 3')
    s.container('Grid','Scroll',None,'GridContainer','columns = 6\ntheme_override_constants/h_separation = 8\ntheme_override_constants/v_separation = 3')
    s.save('main_hero_bag.tscn')
    s=InventoryScene('main_hero_bag_cell.gd')
    s.node('Cell','Button',rect=(0,0,110,107),props=f'script = {s.script}\ncustom_minimum_size = Vector2(110,107)\nflat = true\nfocus_mode = 0\nmouse_filter = 1')
    s.art('Empty','.',(0,0,110,103),'empty')
    s.node('Frame','TextureRect','.',(0,0,100,100),'expand_mode = 1\nmouse_filter = 2')
    s.node('Icon','TextureRect','.',(4,4,92,92),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.node('Rank','TextureRect','.',(0,0,48,33),f'texture = {s.ext("Texture2D","res://assets/runtime/hero_roster/rank.png")}\nexpand_mode = 1\nmouse_filter = 2')
    s.label('Tier','Rank',(3,0,19,32),'Ⅰ',25,1)
    s.label('Quantity','.',(5,70,92,29),'',25,2)
    s.save('main_hero_bag_cell.tscn')
    s=InventoryScene('main_equipment_detail.gd')
    s.node('EquipmentDetail','Control',rect=(0,0,720,1280),props=f'script = {s.script}\nmouse_filter = 0')
    s.fill('Shade','.','Color(0,0,0,0.76)')
    s.hit('Outside','.',(0,0,720,1280));s.nodes[-1]+='\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_right = 0.0\noffset_bottom = 0.0'
    s.node('Panel','Control','.',(71,333,578,516),'mouse_filter = 0')
    s.art('Art','Panel',(0,0,578,516),'panel')
    s.label('Title','Panel',(106,18,366,45),'',27,1)
    s.hit('Share','Panel',(451,13,93,43));s.art('Icon','Panel/Share',(0,3,36,36),'share')
    s.label('Text','Panel/Share',(35,0,59,39),'分享',23,1,'Color(0.15,0.75,0.17,1)')
    s.art('Line','Panel/Share',(34,36,54,4),'underline')
    s.art('Line','Panel',(40,68,498,4),'line')
    s.node('Item','Control','Panel',(40,89,110,110),'mouse_filter = 2')
    s.node('Frame','TextureRect','Panel/Item',(0,0,110,110),'expand_mode = 1\nmouse_filter = 2')
    s.node('Icon','TextureRect','Panel/Item',(6,6,98,98),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.node('Rank','TextureRect','Panel/Item',(0,0,40,27),f'texture = {s.ext("Texture2D","res://assets/runtime/hero_roster/rank.png")}\nexpand_mode = 1\nmouse_filter = 2')
    s.label('Value','Panel/Item/Rank',(4,0,18,25),'Ⅰ',22,1)
    s.art('Star','Panel/Item',(41,84,30,28),'star')
    s.label('StarTitle','Panel',(165,97,64,45),'星级',23)
    s.art('Star','Panel',(219,101,38,37),'star')
    s.label('Attribute','Panel',(165,143,225,45),'',25)
    s.hit('Buyback','Panel',(420,113,115,47));s.art('Art','Panel/Buyback',(0,0,115,47),'buyback');s.label('Text','Panel/Buyback',(0,0,115,47),'回购装备',22,1)
    s.resources.append('[sub_resource type="StyleBoxFlat" id="AffixBody"]\nbg_color = Color(0.016,0.061,0.075,0.7)\nborder_color = Color(0.012,0.033,0.04,1)\nborder_width_left = 4\nborder_width_right = 4\nborder_width_top = 4\nborder_width_bottom = 4\ncorner_radius_top_left = 16\ncorner_radius_top_right = 16\ncorner_radius_bottom_left = 16\ncorner_radius_bottom_right = 16')
    s.node('AffixBody','Panel','Panel',(25,225,528,180),'theme_override_styles/panel = SubResource("AffixBody")\nmouse_filter = 2')
    s.node('Affixes','RichTextLabel','Panel',(38,241,502,148),'bbcode_enabled = true\nscroll_active = true\nmouse_filter = 0\ntheme_override_font_sizes/normal_font_size = 25')
    s.hit('Refine','Panel',(214,411,150,100))
    # The supplied client uses a cyan geometric diamond for this button.
    for name,points,color in [('Wings','0,50,34,15,116,15,150,50,116,85,34,85','0.005,0.025,0.03,1'),('Edge','23,50,75,0,127,50,75,100','0.004,0.015,0.02,1'),('Outer','29,50,75,6,121,50,75,94','0.15,0.42,0.51,1'),('Inset','34,50,75,11,116,50,75,89','0.025,0.11,0.15,1'),('Rim','39,50,75,16,111,50,75,84','0.28,0.65,0.73,1'),('Fill','42,50,75,20,108,50,75,80','0.06,0.27,0.34,1')]:
        s.nodes.append(f'[node name="{name}" type="Polygon2D" parent="Panel/Refine"]\npolygon = PackedVector2Array({points})\ncolor = Color({color})')
    s.label('Text','Panel/Refine',(25,28,100,43),'洗练',27,1)
    s.label('CloseHint','.',(130,899,460,50),'点击空白处关闭界面',23,1,'Color(0.72,0.81,0.82,1)')
    s.node('Confirm','Control','.',props='anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 0\nvisible = false')
    s.fill('Shade','Confirm','Color(0,0,0,0.55)')
    s.node('Card','Control','Confirm',(95,510,530,260),'mouse_filter = 0')
    s.art('Art','Confirm/Card',(0,0,530,260),'panel')
    s.label('Text','Confirm/Card',(26,24,478,116),'',27,1);s.nodes[-1]+='\nautowrap_mode = 2'
    for name,x,text in [('Cancel',42,'取消'),('Accept',292,'确认回购')]:
        s.hit(name,'Confirm/Card',(x,169,196,55));s.art('Art','Confirm/Card/'+name,(0,0,196,55),'buyback');s.label('Text','Confirm/Card/'+name,(0,0,196,55),text,25,1)
    s.save('main_equipment_detail.tscn')


if __name__=='__main__':main()
