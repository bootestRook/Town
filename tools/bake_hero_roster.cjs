// Bake original Spine idle at 30 Hz, preserving a fixed union framing.
const fs=require('fs'),path=require('path'),http=require('http');
const root=path.resolve(__dirname,'..');
const {chromium}=require(path.join(root,'.godot/bake_tools/node_modules/playwright'));
const jobs=JSON.parse(fs.readFileSync(path.join(root,'art_source/hero_roster/poses.json'),'utf8'));
const server=http.createServer((req,res)=>{
 const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));
 if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json','.png':'image/png','.atlas':'text/plain'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage();await page.goto(base+'/art_source/hero_roster/poses.json');
  await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi.js/dist/pixi.js'});
  await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi-spine/dist/pixi-spine.js'});
  const metadata=[];
  for(const job of jobs){
   const result=await page.evaluate(async({job,base})=>{
    const data=(await PIXI.Assets.load(base+'/'+job.skeleton)).spineData;
    const model=new PIXI.spine.Spine(data);model.autoUpdate=false;
    model.skeleton.setSkinByName(job.skin);model.skeleton.setSlotsToSetupPose();
    const duration=data.findAnimation('idl').duration,frames=Math.ceil(duration*30),step=duration/frames;
    model.state.setAnimation(0,'idl',true);model.update(0);
    const weapon=await PIXI.Assets.load(base+'/'+job.weapon);
    function parts(){
     for(let i=0;i<model.skeleton.slots.length;i++)if(job.hidden.includes(model.skeleton.slots[i].data.name)){model.skeleton.slots[i].setAttachment(null);model.slotContainers[i].visible=false;}
     for(const name of Object.values(job.weapon_slots)){
      const slot=model.skeleton.findSlot(name),i=model.skeleton.slots.indexOf(slot);
      model.slotContainers[i].visible=name===job.weapon_slots['1'];
      if(name!==job.weapon_slots['1'])slot.setAttachment(null);
     }
     model.hackTextureBySlotName(job.weapon_slots['1'],weapon);
    }
    let bx0=Infinity,by0=Infinity,bx1=-Infinity,by1=-Infinity;
    for(let n=0;n<frames;n++){parts();const b=model.getLocalBounds();bx0=Math.min(bx0,b.x);by0=Math.min(by0,b.y);bx1=Math.max(bx1,b.x+b.width);by1=Math.max(by1,b.y+b.height);model.update(step);}
    const scale=Math.min(244/(bx1-bx0),244/(by1-by0));
    model.scale.set(scale);model.position.set(128-(bx0+bx1)*scale/2,250-by1*scale);
    model.state.setAnimation(0,'idl',true);model.update(0);
    const renderer=PIXI.autoDetectRenderer({width:256,height:256,backgroundAlpha:0,antialias:true});
    const scene=new PIXI.Container();scene.addChild(model);
    const copies=[];let x0=256,y0=256,x1=0,y1=0;
    for(let n=0;n<frames;n++){
     parts();renderer.render(scene);
     const copy=document.createElement('canvas');copy.width=256;copy.height=256;
     const ctx=copy.getContext('2d');ctx.drawImage(renderer.view,0,0);copies.push(copy);
     const pixels=ctx.getImageData(0,0,256,256).data;
     for(let y=0;y<256;y++)for(let x=0;x<256;x++)if(pixels[(y*256+x)*4+3]>0){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}
     model.update(step);
    }
    const columns=Math.ceil(Math.sqrt(frames)),output=document.createElement('canvas');
    output.width=columns*256;output.height=Math.ceil(frames/columns)*256;
    const w=x1-x0+1,h=y1-y0+1,k=Math.min(244/w,244/h),ctx=output.getContext('2d');
    copies.forEach((copy,n)=>ctx.drawImage(copy,x0,y0,w,h,(n%columns)*256+128-w*k/2,Math.floor(n/columns)*256+250-h*k,w*k,h*k));
    const png=output.toDataURL('image/png').split(',')[1];renderer.destroy();model.destroy();return {png,frames,columns,duration};
   },{job,base});
   fs.writeFileSync(path.join(root,'art_source/hero_roster',job.name+'.png'),Buffer.from(result.png,'base64'));
   metadata.push({id:'idle.'+job.appearance,appearance:job.appearance,resource_id:'hero_roster.'+job.name,frames:result.frames,columns:result.columns,duration:result.duration});
  }
  fs.writeFileSync(path.join(root,'art_source/hero_roster/idle.json'),JSON.stringify(metadata,null,2)+'\n');
  console.log('Baked '+jobs.length+' complete source Spine idle loops.');
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
