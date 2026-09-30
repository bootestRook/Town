// Offline-only converter. Run after import_building_reference.py.
const fs = require('fs'), path = require('path'), http = require('http');
const root = path.resolve(__dirname, '..');
const { chromium } = require(path.join(root, '.godot/bake_tools/node_modules/playwright'));
const jobs = JSON.parse(fs.readFileSync(path.join(root, 'art_source/operations/bake_jobs.json')));
const server = http.createServer((req, res) => {
  const file = path.resolve(root, '.' + decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {res.writeHead(404);res.end();return;}
  const ext = path.extname(file);
  res.setHeader('Content-Type', ({'.js':'text/javascript','.json':'application/json','.png':'image/png','.atlas':'text/plain'})[ext] || 'text/plain');
  res.end(fs.readFileSync(file));
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({channel:'msedge', headless:true, args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  try {
    const page = await browser.newPage();
    await page.goto(base + '/art_source/operations/bake_jobs.json');
    await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi.js/dist/pixi.js'});
    await page.addScriptTag({url:base+'/.godot/bake_tools/node_modules/pixi-spine/dist/pixi-spine.js'});
    for (const job of jobs) {
      for (const animation of [job.animation]) {
        const result = await page.evaluate(async ({job, animation, base}) => {
          const app = new PIXI.Application({width:job.width*job.frames,height:job.height,backgroundAlpha:0,preserveDrawingBuffer:true,antialias:true});
          const data = await PIXI.Assets.load(base+'/'+job.skeleton);
          const model = new PIXI.spine.Spine(data.spineData);
          const skin = data.spineData.skins.find(s => s.name !== 'default');
          if (skin) {model.skeleton.setSkinByName(skin.name);model.skeleton.setSlotsToSetupPose();}
          model.autoUpdate = false;
          model.state.setAnimation(0, animation, true);
          model.update(0);
          const bounds = model.getLocalBounds();
          const scale = Math.min((job.width-18)/bounds.width,(job.height-18)/bounds.height);
          const originX = job.width/2 - (bounds.x+bounds.width/2)*scale;
          const originY = job.height-8 - (bounds.y+bounds.height)*scale;
          const duration = model.state.getCurrent(0).animation.duration || 1;
          for (let i=0;i<job.frames;i++) {
            const frame = new PIXI.spine.Spine(data.spineData);
            if (skin) {frame.skeleton.setSkinByName(skin.name);frame.skeleton.setSlotsToSetupPose();}
            frame.autoUpdate=false; frame.state.setAnimation(0,animation,true);frame.update(duration*i/job.frames);
            frame.scale.set(scale);frame.position.set(originX+job.width*i,originY);app.stage.addChild(frame);
          }
          app.renderer.render(app.stage);
          const png=app.view.toDataURL('image/png').split(',')[1];app.destroy(true);return {png,duration,scale};
        },{job,animation,base});
        const filename=job.name+'_'+animation+'.png';
        fs.writeFileSync(path.join(root,'art_source/operations',filename),Buffer.from(result.png,'base64'));
        console.log(filename, 'duration',result.duration,'scale',result.scale);
      }
    }
  } finally { await browser.close();server.close(); }
})().catch(e=>{console.error(e);server.close();process.exitCode=1});
