// Original RewardBgAnim: entrance followed by the uninterrupted 10.6 s loop.
const fs=require('fs'),path=require('path'),http=require('http');
const root=path.resolve(__dirname,'..');
const {chromium}=require(path.join(root,'.godot/bake_tools/node_modules/playwright'));
const server=http.createServer((req,res)=>{const p=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!p.startsWith(root+path.sep)||!fs.existsSync(p)){res.writeHead(404);res.end();return;}res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json','.png':'image/png','.atlas':'text/plain'})[path.extname(p)]||'text/plain');res.end(fs.readFileSync(p));});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}`;const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});try{
const page=await browser.newPage();await page.goto(base+'/art_source/recruitment/provenance.json');
await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi.js/dist/pixi.js'});await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi-spine/dist/pixi-spine.js'});
for(const [name,animation,frames] of [['reward_enter','js_welcome',80],['reward_loop','js_welcome_XH',64]]){
const result=await page.evaluate(async({base,animation,frames})=>{
const data=(await PIXI.Assets.load(base+'/art_source/recruitment/spine/jiesuanmianban.json')).spineData;
const model=new PIXI.spine.Spine(data);model.autoUpdate=false;model.state.setAnimation(0,'js_welcome',false);model.update(2.6667);model.state.setAnimation(0,'js_welcome_XH',true);model.update(.1);
const b=model.getLocalBounds();const baseScale=Math.min(610/b.width,175/b.height);const scale=baseScale*1.78;const centerX=b.x+b.width/2+13.5/baseScale,centerY=b.y+b.height/2+22.5/baseScale;
model.state.setAnimation(0,animation,false);const duration=model.state.getCurrent(0).animation.duration;
const app=new PIXI.Application({width:2480,height:Math.ceil(frames/4)*180,backgroundAlpha:0,antialias:true});
for(let i=0;i<frames;i++){const f=new PIXI.spine.Spine(data);f.autoUpdate=false;if(animation.endsWith('_XH')){f.state.setAnimation(0,'js_welcome',false);f.update(2.6667);}f.state.setAnimation(0,animation,false);f.update(duration*i/frames);f.scale.set(scale);f.position.set((i%4)*620+310-centerX*scale,Math.floor(i/4)*180+90-centerY*scale);const cell=new PIXI.Container();const mask=new PIXI.Graphics().beginFill(0xffffff).drawRect((i%4)*620,Math.floor(i/4)*180,620,180).endFill();cell.addChild(f);cell.mask=mask;app.stage.addChild(cell,mask);}
app.renderer.render(app.stage);const png=app.view.toDataURL('image/png').split(',')[1];app.destroy(true);return{png,duration};},{base,animation,frames});
for(const dir of ['art_source','assets/runtime']){const target=path.join(root,dir,'diamond_shop',name+'.png');fs.writeFileSync(target,Buffer.from(result.png,'base64'));const meta=JSON.parse(fs.readFileSync(target+'.json'));meta.duration=result.duration;fs.writeFileSync(target+'.json',JSON.stringify(meta,null,2)+'\n');}
console.log(name,frames,result.duration);
}
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
