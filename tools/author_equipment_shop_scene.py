"""Fixed source equipment shop surfaces; only inventory and hero rows are dynamic."""
from author_building_scenes import Scene
from author_battle_horn_scene import art
from author_life_page import button, overlay, rich
from author_equipment_theme import theme

def image(s,name,parent,rect,key): art(s,name,parent,rect,'equipment_shop/'+key)
def hit(s,name,parent,rect,text='',key=''):
    button(s,name,parent,rect)
    full=name if parent=='.' else parent+'/'+name
    if key:image(s,'Art',full,(0,0,rect[2],rect[3]),key)
    if text:s.label('Text',full,(0,0,rect[2],rect[3]),text,26,1,'Color(1,0.92,0.08,1)')
def icon(s,name,parent,rect):
    s.node(name,'TextureRect',parent,rect,'expand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
def topbar(s,left=270):
    s.tex('Topbar','.',(0,0,750,63),'topbar')
    for name,x,folder,asset in [('Gold',left,'hero_camp','coin_bar'),('Diamond',left+236,'life','diamond_bar')]:
        # Life source files are stored under life_ui.
        folder='life_ui' if folder=='life' else folder
        art(s,name+'Bar','.',(x,10,176,44),folder+'/'+asset)
        s.label(name+'Value','.',(x+43,8,123,48),'',26,1,'Color(1,1,1,1)')
        hit(s,name+'Add','.',(x,10,176,44))
def main():
    s=Scene('equipment_shop_page.gd');s.node('EquipmentShop','Control',None,(0,0,750,1334),f'script = {s.script}\nclip_contents = true\ntheme = {theme(s)}')
    art(s,'Backdrop','.',(0,60,750,440),'hero_camp/backdrop');art(s,'Body','.',(0,422,750,912),'hero_camp/body')
    art(s,'Banner','.',(19,97,712,204),'hero_camp/banner')
    icon(s,'Building','.',(126,123,185,154))
    s.label('Title','.',(332,119,330,57),'武器店 Lv.3',32,1,'Color(1,0.92,0.06,1)')
    s.label('Description','.',(329,213,367,50),'打造和售卖武器的建筑',24,1)
    art(s,'UpgradePanel','.',(34,321,684,116),'hero_camp/upgrade_panel')
    for name,x in [('ChainLeft',84),('ChainRight',641)]:art(s,name,'.',(x,262,29,100),'hero_camp/chain')
    rich(s,'Condition','.',(132,357,382,47),26)
    s.button('Upgrade','.',(545,361,145,52),'升级','upgrade',27)
    hit(s,'Go','.',(545,351,145,64),'前往')
    art(s,'Section','.',(193,465,367,62),'hero_camp/section');s.label('SectionText','.',(219,477,312,40),'可打造配方',27,1)
    s.button('Tier','.',(27,523,136,57),'一阶 ▾','tier_menu',27)
    hit(s,'ListMode','.',(25,525,188,55))
    art(s,'Box','ListMode',(0,0,50,50),'battle_horn/checkbox');art(s,'Check','ListMode',(0,0,50,50),'battle_horn/checked')
    s.label('Text','ListMode',(61,0,127,55),'列表模式',25)
    image(s,'CapacityPanel','.',(300,536,159,38),'capacity');s.label('Capacity','.',(285,526,190,56),'库存 0/300',25,1)
    hit(s,'Resolve','.',(588,528,140,50),'分解','resolve')
    s.node('Scroll','ScrollContainer','.',(27,588,699,629),'horizontal_scroll_mode = 0')
    s.node('Grid','GridContainer','Scroll',props='layout_mode = 2\ncolumns = 4\ntheme_override_constants/h_separation = 10\ntheme_override_constants/v_separation = 9')
    s.node('Heroes','ScrollContainer','.',(24,532,704,679),'horizontal_scroll_mode = 0')
    s.node('Rows','VBoxContainer','Heroes',props='layout_mode = 2\nsize_flags_horizontal = 3\ntheme_override_constants/separation = 16')
    art(s,'Bottom','.',(0,1217,750,117),'hero_camp/bottom')
    for i,label in enumerate(['配方','图纸','货架','英雄']):
        hit(s,'Tab'+str(i),'.',(2+i*146,1225,144,109),'','tab'+str(i)+'_off')
        s.label('Text','Tab'+str(i),(0,78,144,30),label,26,1,'Color(0.85,0.91,0.9,1)')
    topbar(s);button(s,'Help','.',(14,-5,64,92),'help')
    overlay(s,'TierMenu');s.nodes[-3]+='\nz_index = 3'
    s.tex('Panel','TierMenu',(27,581,165,330),'dialog')
    for i,label in enumerate(['一阶','二阶','三阶','四阶','五阶']):
        s.button('Tier'+str(i+1),'TierMenu',(38,591+i*61,142,56),label,'tier_menu',26)
    for name,scene in [('Trade','equipment_trade.tscn'),('Dialog','equipment_dialog.tscn')]:
        resource=s.ext('PackedScene','res://scenes/town/'+scene);s.nodes.append(f'[node name="{name}" parent="." instance={resource}]\nvisible = false')
    s.save('equipment_shop_page.tscn')
    from pathlib import Path
    p=Path(__file__).resolve().parents[1]/'scenes/town/equipment_shop_page.tscn'
    contract='; THESIS: Faithful source equipment shops, with real crafting and hero purchases.\n; OWN-WORLD: Original fantasy inked sprites, teal panels, purple banners, cream type.\n; STORY: Browse recipes, craft, manage stock, summon, trade each equipment part.\n; FIRST VIEWPORT: Chained building header above a four-column grid and four bottom tabs.\n; FORM: User-pinned source screenshots; extension of shipped weapon shop, no concept roll.\n; FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance\n'
    p.write_text(contract+p.read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
    cards();dialog();trade()

def cards():
    s=Scene('equipment_item_card.gd');s.node('Item','Button',None,props=f'script = {s.script}\ncustom_minimum_size = Vector2(166,214)\nflat = true\nfocus_mode = 0')
    image(s,'Background','.',(0,0,166,214),'cell')
    icon(s,'Quality','.',(24,21,119,119));icon(s,'Icon','.',(28,24,109,109));icon(s,'Tier','.',(24,21,45,26))
    s.label('Name','.',(5,152,156,43),'',21,1,'Color(0.79,0.85,0.85,1)')
    s.label('Count','.',(37,111,105,29),'',22,2,'Color(1,1,1,1)')
    s.label('Selected','.',(117,7,41,41),'✓',28,1,'Color(0.2,1,0.15,1)')
    s.label('Stars','.',(36,117,98,23),'',17,1,'Color(1,0.8,0.05,1)')
    s.label('Locked','.',(9,5,96,30),'已锁定',19)
    s.label('Detail','.',(173,48,445,92),'',23)
    s.save('equipment_item_card.tscn')
    s=Scene('equipment_hero_row.gd');s.node('Hero','Control',None,props=f'script = {s.script}\ncustom_minimum_size = Vector2(704,192)')
    image(s,'Background','.',(0,0,704,192),'hero_row')
    resource=s.ext('PackedScene','res://scenes/town/equipment_hero_card.tscn');s.nodes.append(f'[node name="Card" parent="." instance={resource}]\noffset_left = 17.0\noffset_top = 9.0')
    s.label('Current','.',(285,8,160,37),'当前装备',24,1)
    for i,x in enumerate([236,342]):
        p='Slot'+str(i);s.node(p,'Control','.',(x,66,112,111))
        icon(s,'Quality',p,(0,0,89,89));icon(s,'Icon',p,(2,0,86,86));icon(s,'Tier',p,(0,0,35,21))
        s.label('Stars',p,(6,73,78,24),'',18,1,'Color(1,0.8,0.05,1)')
        s.label('Empty',p,(-12,23,112,42),'暂无装备',20,1)
        icon(s,'Rating',p,(60,55,44,44));hit(s,'Open',p,(0,0,105,105))
    s.label('Job','.',(568,3,130,34),'战士',21,2,'Color(0.5,0.62,0.64,1)')
    s.button('Summon','.',(541,65,145,52),'召唤','upgrade',26)
    s.save('equipment_hero_row.tscn')
    s=Scene();s.node('Offer','Control',None,props='custom_minimum_size = Vector2(704,166)')
    image(s,'Background','.',(0,0,704,166),'offer')
    icon(s,'Quality','.',(23,23,118,118));icon(s,'Icon','.',(28,26,106,106));icon(s,'Tier','.',(25,22,45,26))
    s.label('Stars','.',(30,115,102,25),'',19,1,'Color(1,0.8,0.05,1)')
    s.label('Name','.',(184,21,345,38),'',26)
    rich(s,'Power','.',(184,99,235,41),26)
    image(s,'Up','.',(434,100,39,39),'up')
    s.tex('Money','.',(539,17,143,39),'money_bg');s.tex('Coin','.',(539,13,43,43),'coin')
    s.label('Price','.',(582,10,99,50),'',29,1,'Color(1,1,1,1)')
    hit(s,'Buy','.',(541,56,145,52),'交易','trade')
    s.save('equipment_offer.tscn')

def dialog():
    s=Scene('equipment_shop_dialog.gd');s.node('Dialog','Control',None,(0,0,750,1334),f'script = {s.script}\nz_index = 4')
    s.node('Shade','ColorRect','.',(0,0,750,1334),'color = Color(0,0,0,0.76)')
    image(s,'Panel','.',(30,208,690,895),'craft_panel')
    s.label('Title','.',(120,229,510,60),'打造装备',32,1)
    icon(s,'Quality','.',(302,330,144,144));icon(s,'Icon','.',(308,336,132,132));icon(s,'Tier','.',(302,330,46,28))
    s.label('Name','.',(100,485,550,45),'',28,1)
    rich(s,'Detail','.',(112,548,526,119),25)
    s.node('Materials','HBoxContainer','.',(76,685,598,117),'theme_override_constants/separation = 27\nalignment = 1\nmouse_filter = 2')
    s.node('Slider','HSlider','.',(185,824,585,69),'scale = Vector2(0.65,0.65)\nmin_value = 1.0\nmax_value = 10.0\nstep = 1.0\nvalue = 1.0')
    s.button('Minus','.',(98,822,70,57),'−','upgrade');s.button('Plus','.',(583,822,70,57),'+','upgrade')
    s.label('Count','.',(287,881,180,46),'1',29,1)
    s.button('Max','.',(535,882,118,48),'最大','upgrade',23)
    hit(s,'Accept','.',(427,967,226,75),'打造','craft_button');s.button('Cancel','.',(96,967,226,75),'取消')
    s.node('Amount','LineEdit','.',(181,820,388,61),'visible = false\nplaceholder_text = "请输入金币数量"\nalignment = 1\ntheme_override_font_sizes/font_size = 27')
    s.button('Lock','.',(278,822,195,61),'锁定','upgrade',25)
    s.save('equipment_dialog.tscn')

def trade():
    s=Scene('equipment_trade_page.gd');s.node('Trade','Control',None,(0,0,750,1334),f'script = {s.script}')
    art(s,'Body','.',(0,0,750,1334),'hero_camp/body')
    s.node('Backdrop','Control','.',(0,63,750,495),'clip_contents = true\nmouse_filter = 2')
    art(s,'Background','Backdrop',(-760,-319,1839,884),'hero_detail/background_4')
    image(s,'Header','.',(0,495,750,79),'trade_header')
    s.node('Portrait','TextureRect','.',(24,137,275,275),f'script = {s.ext("Script","res://src/features/town/presentation/hero_idle_portrait.gd")}\nexpand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    s.label('HeroName','.',(32,109,263,50),'',32,1,'Color(0.17,1,0.25,1)')
    icon(s,'Job','.',(249,296,44,44))
    art(s,'PowerIcon','.',(64,382,53,49),'hero_detail/power')
    s.label('HeroPower','.',(106,379,152,63),'',46,1,'Color(1,0.79,0.12,1)')
    s.nodes[-1]+=f'\ntheme_override_fonts/font = {s.ext("FontFile","res://assets/runtime/hero_detail/power.fnt")}'
    image(s,'WalletBar','.',(59,432,211,36),'hero_gold');s.tex('Coin','.',(54,427,37,37),'coin')
    s.label('Wallet','.',(91,423,155,50),'',27,1,'Color(1,1,1,1)')
    hit(s,'Donate','.',(239,422,44,50),'+')
    image(s,'EquipmentPanel','.',(348,83,392,412),'equipment_panel')
    s.label('EquipmentName','.',(382,96,315,39),'',25,1,'Color(0.87,0.27,0.1,1)')
    icon(s,'Quality','.',(368,161,89,89));icon(s,'Icon','.',(371,164,83,83));icon(s,'Tier','.',(368,161,34,21))
    s.label('Stars','.',(374,222,77,23),'',18,1,'Color(1,0.8,0.05,1)')
    s.label('EquipmentPower','.',(477,172,208,60),'',23)
    rich(s,'Affixes','.',(375,253,331,225),23)
    art(s,'Section','.',(193,521,367,62),'hero_camp/section');s.label('SectionText','.',(227,533,298,40),'装备预览',27,1)
    s.node('Offers','ScrollContainer','.',(23,590,710,614),'horizontal_scroll_mode = 0')
    s.node('Rows','VBoxContainer','Offers',props='layout_mode = 2\ntheme_override_constants/separation = 16')
    art(s,'Bottom','.',(0,1217,750,117),'hero_camp/bottom')
    for i in range(2):
        hit(s,'Part'+str(i),'.',(4+i*146,1225,141,103))
        icon(s,'Art','Part'+str(i),(0,0,141,103))
        s.label('Text','Part'+str(i),(0,76,141,27),['上衣','裤子'][i],26,1,'Color(0.85,0.91,0.9,1)')
    topbar(s,4)
    s.save('equipment_trade.tscn')

def hero_card():
    s=Scene('equipment_hero_card.gd');s.node('Card','Control',None,(0,0,134,176),f'script = {s.script}\nmouse_filter = 2')
    hit(s,'Open','.',(0,0,134,176))
    icon(s,'Quality','Open',(0,0,124,176))
    s.node('Portrait','TextureRect','Open',(1,28,126,126),f'script = {s.ext("Script","res://src/features/town/presentation/hero_idle_portrait.gd")}\nexpand_mode = 1\nstretch_mode = 5\nmouse_filter = 2')
    art(s,'Rank','Open',(0,4,28,21),'hero_roster/rank')
    s.label('Level','Open',(25,3,85,24),'',20,0,'Color(0.18,1,0.3,1)')
    icon(s,'Job','Open',(0,37,29,23));icon(s,'Element','Open',(107,0,33,33))
    s.label('Name','Open',(6,129,110,24),'',20,1,'Color(0.18,1,0.3,1)')
    for i in range(4):icon(s,'Star%d'%i,'Open',(114,124-i*26,28,28))
    hit(s,'Locate','.',(0,150,124,27))
    s.tex('Plate','Locate',(0,0,124,27),'money_bg');art(s,'PowerIcon','Locate',(0,-5,26,30),'hero_roster/power_icon')
    s.label('Power','Locate',(25,-1,96,29),'',27,1,'Color(1,1,1,1)')
    s.save('equipment_hero_card.tscn')

if __name__=='__main__': main();hero_card()
