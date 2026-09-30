"""Fixed source hero drawer/card structure; only roster entries are dynamic."""
from author_main_ui_scenes import MainScene


class HeroScene(MainScene):
    def art(self, name, parent, rect, asset):
        self.node(name, 'TextureRect', parent, rect,
                  f'texture = {self.ext("Texture2D", "res://assets/runtime/hero_roster/"+asset+".png")}\nexpand_mode = 1\nmouse_filter = 2')


def main():
    s = HeroScene('main_hero_roster.gd')
    s.node('HeroRoster', 'Control', rect=(0, 0, 720, 600), props=f'script = {s.script}\nmouse_filter = 0')
    s.fill('Base', '.', 'Color(0.043,0.094,0.114,1)')
    s.art('Header', '.', (0,0,720,77), 'body')
    for name,x,icon,label in [('Lineup',6,'lineup','修改阵容'),('Dispatch',170,'dispatch','地图派遣')]:
        s.node(name,'Button','.',(x,12,151,51),'flat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')
        s.art('Art',name,(0,4,151,43),icon)
        s.label('Text',name,(39,4,108,43),label,22,1)
    s.label('Count','.',(480,12,169,53),'',27,1)
    s.node('Close','TextureButton','.',(630,-40,90,84),f'texture_normal = {s.ext("Texture2D","res://assets/runtime/hero_roster/close.png")}\nignore_texture_size = true\nstretch_mode = 0\nfocus_mode = 0')
    s.node('Scroll','ScrollContainer','.',props='anchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 21.0\noffset_top = 87.0\noffset_right = -8.0\noffset_bottom = -4.0\nhorizontal_scroll_mode = 0')
    s.container('Grid','Scroll',None,'GridContainer','columns = 3\ntheme_override_constants/h_separation = 15\ntheme_override_constants/v_separation = 12')
    s.save('main_hero_roster.tscn')
    s=HeroScene('main_hero_card.gd')
    s.node('Card','Control',rect=(0,0,217,265),props=f'custom_minimum_size = Vector2(217,265)\nscript = {s.script}\nmouse_filter = 2')
    s.node('Open','Button','.',(0,0,217,265),'flat = true\nfocus_mode = 0\nmouse_filter = 1\nmouse_default_cursor_shape = 2')
    s.art('Quality','Open',(5,8,207,254),'quality_4')
    s.node('Portrait','TextureRect','Open',(13,45,191,182),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.nodes[-1]+=f'\nscript = {s.ext("Script","res://src/features/town/presentation/hero_idle_portrait.gd")}'
    s.art('Rank','Open',(0,27,51,38),'rank')
    s.label('RankValue','Open',(5,27,22,35),'Ⅰ',26,1)
    s.art('Job','Open',(0,68,51,38),'job_1')
    s.art('Element','Open',(171,2,45,45),'element_1')
    s.label('Name','Open',(39,-1,137,25),'',23,1,'Color(0.18,1,0.3,1)')
    s.label('Level','Open',(44,23,128,23),'',22,1,'Color(0.18,1,0.3,1)')
    s.node('Stars','Control','Open',(21,177,176,40),'mouse_filter = 2')
    for i in range(4):
        s.node('Star'+str(i),'TextureRect','Open/Stars',(i*41,0,40,40),'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.node('Locate','Button','.',(4,213,208,49),'flat = true\nfocus_mode = 0\nmouse_filter = 1\nmouse_default_cursor_shape = 2')
    s.art('Plate','Locate',(0,0,208,49),'power_plate')
    s.label('Power','Locate',(40,3,105,42),'',25,1)
    s.save('main_hero_card.tscn')


if __name__ == '__main__': main()
