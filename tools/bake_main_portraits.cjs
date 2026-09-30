// Offline source Spine idle portraits; no generated substitute artwork.
const fs=require('fs'),path=require('path'),http=require('http');
const root=path.resolve(__dirname,'..');
const {chromium}=require(path.join(root,'.godot/bake_tools/node_modules/playwright'));
const jobs=JSON.parse(fs.readFileSync(path.join(root,'art_source/main_ui/portrait_jobs.json'),'utf8'));
const server=http.createServer((req,res)=>{
 const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));
 if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json','.png':'image/png','.atlas':'text/plain'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base=`http://127.0.0.1:${server.address().port}`;
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try {
  const page=await browser.newPage();await page.goto(base+'/art_source/main_ui/portrait_jobs.json');
  await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi.js/dist/pixi.js'});
  await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi-spine/dist/pixi-spine.js'});
  for(const job of jobs){
   const png=await page.evaluate(async({job,base})=>{
    const data=(await PIXI.Assets.load(base+'/'+job.skeleton)).spineData;
    const model=new PIXI.spine.Spine(data);model.autoUpdate=false;
    const animation=data.animations.find(a=>['idl','idle'].includes(a.name));
    if(!animation)throw Error('No source idle animation: '+job.name);
    model.state.setAnimation(0,animation.name,false);model.update(0.05);
    const bounds=model.getLocalBounds();const scale=236/Math.max(bounds.width,bounds.height);
    model.scale.set(scale);model.position.set(128-(bounds.x+bounds.width/2)*scale,128-(bounds.y+bounds.height/2)*scale);
    const renderer=PIXI.autoDetectRenderer({width:256,height:256,backgroundAlpha:0,antialias:true});
    const scene=new PIXI.Container();scene.addChild(model);renderer.render(scene);
    const result=renderer.view.toDataURL('image/png').split(',')[1];renderer.destroy();model.destroy();return result;
   },{job,base});
   const output=path.join(root,job.output);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,Buffer.from(png,'base64'));
  }
  process.stdout.write(`Baked ${jobs.length} source enemy portraits.\n`);
 } finally {await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
