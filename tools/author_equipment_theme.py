"""Native input controls use the source shop palette and original slider sprites."""


def theme(s):
    font = s.ext('FontFile', 'res://assets/runtime/operations/font.ttf')
    handle = s.ext('Texture2D', 'res://assets/runtime/equipment_shop/slider_handle.png')
    track = s.ext('Texture2D', 'res://assets/runtime/equipment_shop/slider_track.png')
    for name, color, border in [
        ('Track', '0.025,0.055,0.065,1', '0.01,0.02,0.025,1'),
        ('Thumb', '0.2,0.37,0.39,1', '0.04,0.08,0.09,1'),
        ('Highlight', '0.34,0.48,0.42,1', '0.78,0.67,0.35,1'),
        ('Input', '0.05,0.1,0.13,1', '0.28,0.43,0.45,1'),
        ('InputFocus', '0.05,0.1,0.13,1', '0.91,0.76,0.37,1'),
        ('ReadOnly', '0.045,0.07,0.085,1', '0.15,0.22,0.24,1'),
    ]:
        s.resources.append(f'[sub_resource type="StyleBoxFlat" id="{name}"]\nbg_color = Color({color})\nborder_width_left = 2\nborder_width_top = 2\nborder_width_right = 2\nborder_width_bottom = 2\nborder_color = Color({border})\ncontent_margin_left = 6.0\ncontent_margin_right = 6.0\ncontent_margin_top = 8.0\ncontent_margin_bottom = 8.0')
    s.resources.append(f'[sub_resource type="StyleBoxTexture" id="SliderTrack"]\ntexture = {track}\ntexture_margin_left = 4.0\ntexture_margin_right = 4.0\ntexture_margin_top = 4.0\ntexture_margin_bottom = 4.0')
    props = [f'default_font = {font}', 'default_font_size = 24']
    for name, color in [('font_color','0.95,0.92,0.76,1'), ('font_placeholder_color','0.55,0.67,0.66,1'), ('font_uneditable_color','0.4,0.5,0.5,1'), ('caret_color','0.95,0.83,0.49,1'), ('selection_color','0.2,0.4,0.42,1')]:
        props.append(f'LineEdit/colors/{name} = Color({color})')
    for kind, values in [('LineEdit', {'normal':'Input','focus':'InputFocus','read_only':'ReadOnly'}), ('VScrollBar', {'scroll':'Track','scroll_focus':'InputFocus','grabber':'Thumb','grabber_highlight':'Highlight','grabber_pressed':'Highlight'}), ('HSlider', {'slider':'SliderTrack','grabber_area':'Thumb','grabber_area_highlight':'Highlight'})]:
        props += [f'{kind}/styles/{key} = SubResource("{value}")' for key,value in values.items()]
    props += [f'HSlider/icons/{name} = {handle}' for name in ['grabber','grabber_highlight','grabber_disabled']]
    s.resources.append('[sub_resource type="Theme" id="WeaponTheme"]\n' + '\n'.join(props))
    return 'SubResource("WeaponTheme")'
