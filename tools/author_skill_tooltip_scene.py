"""Source SkillInfoTips: a nonmodal panel anchored to the selected skill."""
from author_hero_detail_scene import DetailScene


def main():
    s = DetailScene('main_skill_tooltip.gd')
    s.node('SkillTooltip', 'Control', rect=(30,550,660,214), props=f'script = {s.script}\nmouse_filter = 0')
    s.node('Background','NinePatchRect','.',props=f'anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\ntexture = {s.ext("Texture2D","res://assets/runtime/hero_detail/tip_body.png")}\npatch_margin_left = 14\npatch_margin_top = 14\npatch_margin_right = 14\npatch_margin_bottom = 14')
    s.node('Icon','Control','.',(24,18,104,104),'mouse_filter = 2')
    s.node('Art','TextureRect','Icon',(0,0,104,104),'expand_mode = 1\nmouse_filter = 2')
    s.art('Frame','Icon',(-3,-3,110,110),'skill_frame')
    s.art('Corner','Icon',(71,-2,35,33),'skill_level')
    s.label('Level','Icon',(73,-2,31,33),'',27,1)
    s.art('Lock','Icon',(14,14,76,76),'skill_lock');s.nodes[-1]+='\nvisible = false'
    s.label('Title','.',(148,13,329,37),'',24,0,'Color(1,0.94,0.04,1)')
    s.label('Type','.',(479,13,163,37),'',24,2)
    s.label('Unlock','.',(148,49,494,34),'',23,0,'Color(1,0.23,0.29,1)')
    s.node('Text','RichTextLabel','.',(148,54,494,144),'bbcode_enabled = true\nscroll_active = false\nmouse_filter = 2\ntheme_override_font_sizes/normal_font_size = 23\ntheme_override_colors/default_color = Color(0.953,0.953,0.827,1)\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 4\ntheme_override_constants/line_separation = 4')
    s.save('main_skill_tooltip.tscn')


if __name__ == '__main__': main()
