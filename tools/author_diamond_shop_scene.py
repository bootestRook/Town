"""Fixed native recharge layout and reward overlay. No runtime-built skeleton."""
from author_main_ui_scenes import MainScene


class ShopScene(MainScene):
    def art(self,name,parent,rect,asset):
        path=asset if '/' in asset else 'diamond_shop/'+asset
        self.node(name,'TextureRect',parent,rect,f'texture = {self.ext("Texture2D","res://assets/runtime/"+path+".png")}\nexpand_mode = 1\nmouse_filter = 2')

    def hit(self,name,parent,rect):
        self.node(name,'Button',parent,rect,'flat = true\nfocus_mode = 0\nmouse_default_cursor_shape = 2')


def main():
    s=ShopScene('main_diamond_shop.gd')
    s.node('DiamondShop','Control',rect=(0,0,720,1280),props=f'script = {s.script}\nmouse_filter = 0')
    s.fill('Background','.','Color(0.043,0.105,0.13,1)')
    s.node('Banner','Control','.',(0,60,720,298),'clip_contents = true\nmouse_filter = 2')
    s.art('Art','Banner',(0,0,720,350),'banner')
    s.node('Offers','Control','.',(0,404,720,704),'mouse_filter = 2')
    for i in range(6):
        p=f'Offers/Card{i}';x=14+(i%3)*234;y=(i//3)*355
        s.hit(f'Card{i}','Offers',(x,y,224,350));s.nodes[-1]+='\npivot_offset = Vector2(112,175)'
        s.art('Frame',p,(0,0,224,350),'card_'+str(i+1))
        s.art('Icon',p,(27,68,170,108),'gem_'+str(i+1))
        s.label('Amount',p,(0,176,224,51),'',32,1)
        s.label('Bonus',p,(0,213,224,42),'',24,1)
        s.label('Price',p,(31,285.5 if i==0 else 287.5,162,42),'',25,1)
        s.art('Ribbon',p,(-1,-1,127,81),'ribbon')
        s.label('First',p,(-17,51,155,30),'首充双倍',24,1,'Color(1,0.94,0,1)');s.nodes[-1]+='\nrotation = -0.567'
    s.node('Header','Control','.',(0,0,720,62),'mouse_filter = 0')
    s.art('Art','Header',(0,0,720,62),'top')
    s.hit('Help','Header',(10,-2,69,78));s.art('Art','Header/Help',(0,0,69,78),'help')
    for name,x,asset in [('Diamonds',88,'diamonds'),('Coins',258,'coins')]:
        s.hit(name,'Header',(x,6,155,50));s.art('Art','Header/'+name,(0,0,155,50),asset)
        s.label('Value','Header/'+name,(54,0,94,46),'',27,0,'Color(0.85,0.9,0.88,1)')
    s.node('Footer','Control','.',(0,1177,720,103),'mouse_filter = 0')
    s.art('Art','Footer',(0,-22,720,125),'main_ui/bottom')
    s.art('Tab','Footer',(4,0,141,103),'tab');s.label('Text','Footer/Tab',(0,70,141,30),'钻石充值',22,1,'Color(0.8,0.87,0.86,1)')
    s.hit('Back','.',(605,1106,115,106));s.art('Art','Back',(0,0,115,106),'hero_detail/back')
    s.node('Reward','Control','.',(0,0,720,1280),'visible = false\nmouse_filter = 0')
    s.fill('Shade','Reward','Color(0,0,0,0.78)')
    s.node('Body','Control','Reward',(0,402,720,378),'mouse_filter = 2')
    s.art('Panel','Reward/Body',(0,70,720,292),'recruitment/result_body')
    s.art('Rays','Reward/Body',(30,-250,660,640),'recruitment/rays');s.nodes[-1]+='\npivot_offset = Vector2(330,320)'
    s.node('Ribbon','Sprite2D','Reward/Body',props=f'position = Vector2(360,45)\ntexture = {s.ext("Texture2D","res://assets/runtime/diamond_shop/reward_enter.png")}\nhframes = 4\nvframes = 20')
    s.label('Title','Reward/Body',(138,-4,444,98),'恭喜获得',49,1,'Color(1,0.94,0,1)');s.nodes[-1]+='\npivot_offset = Vector2(222,49)'
    s.node('Item','Control','Reward/Body',(298,141,124,158),'mouse_filter = 2\npivot_offset = Vector2(62,62)')
    s.art('Frame','Reward/Body/Item',(0,0,124,124),'operations/quality_4')
    s.art('Icon','Reward/Body/Item',(18,16,88,88),'main_ui/diamond_icon')
    s.label('Amount','Reward/Body/Item',(2,85,118,38),'',26,2)
    s.label('Name','Reward/Body/Item',(-40,124,204,42),'钻石',25,1)
    s.node('Burst','TextureRect','Reward/Body',(170,11,380,380),'expand_mode = 1\nmouse_filter = 2')
    s.label('Hint','Reward',(120,982,480,45),'点击空白处关闭界面',23,1,'Color(0.77,0.87,0.86,1)')
    s.node('HelpPanel','Control','.',(0,0,720,1280),'visible = false\nmouse_filter = 0')
    s.fill('Shade','HelpPanel','Color(0,0,0,0.74)')
    s.node('Body','Control','HelpPanel',(0,374,720,510),'mouse_filter = 0')
    s.art('Art','HelpPanel/Body',(38,0,644,510),'operations/dialog')
    s.label('Title','HelpPanel/Body',(170,28,380,65),'钻石充值',30,1,'Color(1,0.92,0,1)')
    s.label('Text','HelpPanel/Body',(103,146,514,240),'每个档位首次充值，可额外获得同等数量的钻石。\n\n本客户端为模拟充值，不产生真实扣款。',27);s.nodes[-1]+='\nautowrap_mode = 2'
    s.label('Hint','HelpPanel',(120,964,480,45),'点击空白处关闭界面',23,1)
    for name,asset in [('Click','click'),('RewardSound','reward_sound')]:
        s.node(name,'AudioStreamPlayer','.',props=f'stream = {s.ext("AudioStream","res://assets/runtime/diamond_shop/"+asset+".wav")}\nvolume_db = -8.0')
    s.save('main_diamond_shop.tscn')


if __name__=='__main__':main()
