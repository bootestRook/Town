// Offline Spine 3.8 conversion; named parts come from source c25_zww/spine tables.
const fs=require('fs'),path=require('path'),http=require('http');
const root=path.resolve(__dirname,'..');
const {chromium}=require(path.join(root,'.godot/bake_tools/node_modules/playwright'));
const jobs=JSON.parse(fs.readFileSync(path.join(root,'art_source/heroes/bake_jobs.json')));
const server=http.createServer((req,res)=>{
  const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json','.png':'image/png','.atlas':'text/plain'})[path.extname(file)]||'application/octet-stream');
  res.end(fs.readFileSync(file));
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base=`http://127.0.0.1:${server.address().port}`;
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const metadata=process.argv.includes('--missing')?JSON.parse(fs.readFileSync(path.join(root,'art_source/heroes/animations.json'),'utf8')):[];
 try{
  const page=await browser.newPage();
  await page.goto(base+'/art_source/heroes/bake_jobs.json');
  await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi.js/dist/pixi.js'});
  await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi-spine/dist/pixi-spine.js'});
  for(const job of jobs){
   if(process.argv.includes('--missing')&&metadata.some(r=>r.actor===job.name&&r.direction===job.direction))continue;
   const result=await page.evaluate(async({job,base,inspect})=>{
    const data=(await PIXI.Assets.load(base+'/'+job.skeleton)).spineData;
    const weaponTexture=job.weapon?await PIXI.Assets.load(base+'/'+job.weapon):null;
    const animations=data.animations.map(a=>a.name);
    if(inspect){
     const model=new PIXI.spine.Spine(data);model.autoUpdate=false;
     if(job.skin){model.skeleton.setSkinByName(job.skin);model.skeleton.setSlotsToSetupPose();}
     model.state.setAnimation(0,animations.includes('idl')?'idl':'idle',false);model.update(0);
     for(let i=0;i<model.skeleton.slots.length;i++)if(job.hidden.includes(model.skeleton.slots[i].data.name)){model.skeleton.slots[i].setAttachment(null);model.slotContainers[i].visible=false;}
     return {animations,skin:job.skin,visible:model.skeleton.slots.filter(s=>s.getAttachment()).map(s=>s.data.name)};
    }
    const idleAction=animations.includes('idl')?'idl':'idle';
    // Source btCptHeroCharacter.playDeath explicitly uses beatk; ordinary hits flash.
    const actions={idle:idleAction,move:'move',death:job.skin?'beatk':'die'};
    job.attacks.forEach((name,i)=>actions['attack'+(i?i+1:'')]=name);
    const pose=(animation,time,replaceWeapon=true)=>{
     const model=new PIXI.spine.Spine(data);model.autoUpdate=false;
     if(job.skin){model.skeleton.setSkinByName(job.skin);model.skeleton.setSlotsToSetupPose();}
     model.state.setAnimation(0,animation,false);model.update(time);
     for(let i=0;i<model.skeleton.slots.length;i++)if(job.hidden.includes(model.skeleton.slots[i].data.name)){model.skeleton.slots[i].setAttachment(null);model.slotContainers[i].visible=false;}
     if(job.weapon_slots){
      const events=data.animations.find(a=>a.name===animation).timelines.flatMap(t=>t.events||[]);
      const deathEvent=events.find(e=>e.data.name==='die');
      const dropped=animation==='beatk'&&deathEvent&&time>=deathEvent.time;
      const active=job.weapon_slots[dropped?(job.direction==='front'?'2':'9'):(job.direction==='front'?'1':'8')];
      for(const name of Object.values(job.weapon_slots)){
       const slot=model.skeleton.findSlot(name),index=model.skeleton.slots.indexOf(slot);
       if(slot){model.slotContainers[index].visible=name===active;if(name!==active)slot.setAttachment(null);}
      }
      if(replaceWeapon&&weaponTexture&&model.skeleton.findSlot(active)?.getAttachment())model.hackTextureBySlotName(active,weaponTexture);
     }
     return model;
    };
    const scale=job.scale;
    const outputs=[];
    for(const [action,animation] of Object.entries(actions)){
     const seconds=data.animations.find(a=>a.name===animation).duration||1;
     const frames=Math.round(seconds*30)+(action==='death'?1:0);
     const models=Array.from({length:frames},(_,i)=>pose(animation,Math.min(seconds,i/30)));
     const extents=models.map(model=>model.getLocalBounds()).map(b=>({left:b.x*scale,right:(b.x+b.width)*scale,top:b.y*scale,bottom:(b.y+b.height)*scale}));
     // The original skeleton root is the pivot, independent of alpha bounds.
     const half=Math.max(...extents.map(b=>Math.max(-b.left,b.right)+12));
     const width=Math.ceil(half/8)*16;
     const originY=Math.max(0,Math.ceil(12-Math.min(...extents.map(b=>b.top))));
     const height=Math.ceil((Math.max(0,...extents.map(b=>b.bottom))+originY+12)/16)*16;
     const columns=Math.min(8,frames,Math.floor(4096/width)),rows=Math.ceil(frames/columns);
     const app=new PIXI.Application({width:width*columns,height:height*rows,backgroundAlpha:0,preserveDrawingBuffer:true,antialias:true});
     for(let i=0;i<frames;i++){
      const model=models[i];
      model.scale.set(scale);model.position.set(width/2+width*(i%columns),originY+height*Math.floor(i/columns));app.stage.addChild(model);
     }
     app.renderer.render(app.stage);
     outputs.push({action:action.startsWith('attack')?'attack':action,variant:action.startsWith('attack')?Number(action.slice(6)||1):1,key:action,seconds,animation,frames,columns,rows,frame_width:width,frame_height:height,origin_y:originY,png:app.view.toDataURL('image/png').split(',')[1]});
     app.destroy(true);
    }
    return {animations,outputs};
   },{job,base,inspect:process.argv.includes('--inspect')});
   if(!result.outputs){console.log(job.name,job.direction,JSON.stringify(result));continue;}
   for(const out of result.outputs){
    const name=`${job.name}_${job.direction}_${out.key}`;
    fs.writeFileSync(path.join(root,`art_source/heroes/${name}.png`),Buffer.from(out.png,'base64'));
    metadata.push({id:name,actor:job.name,direction:job.direction,action:out.action,variant:out.variant,frames:out.frames,seconds:out.seconds,source_animation:out.animation,columns:out.columns,rows:out.rows,frame_width:out.frame_width,frame_height:out.frame_height,origin_y:out.origin_y});
   }
   console.log(job.name,job.direction,'baked');
  }
  if(metadata.length)fs.writeFileSync(path.join(root,'art_source/heroes/animations.json'),JSON.stringify(metadata,null,2)+'\n');
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
