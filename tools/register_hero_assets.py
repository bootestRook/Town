"""Register baked assets and verify their runtime copies through the normal pipeline."""
import csv
import hashlib
import json
import shutil
import math
from PIL import Image
from PIL.PngImagePlugin import PngInfo
from import_town_reference import ROOT, read_json, write_csv, write_json


def main():
    rows = read_json(ROOT/'art_source/heroes/animations.json')
    jobs = {(r['name'], r['direction']): r for r in read_json(ROOT/'art_source/heroes/bake_jobs.json')}
    with (ROOT/'data/source/resource_bindings.csv').open(encoding='utf-8') as stream:
        bindings = list(csv.DictReader(stream))
    bindings = [r for r in bindings if not r['id'].startswith('heroes.')]
    assets={}
    for row in rows:
        source=ROOT/f'art_source/heroes/{row["id"]}.png'
        columns=min(8,row['frames'],4096//row['frame_width'])
        if columns != row['columns'] or source.stat().st_size > 8388608:
            with Image.open(source) as atlas:
                packed=Image.new('RGBA',(columns*row['frame_width'],math.ceil(row['frames']/columns)*row['frame_height']))
                for i in range(row['frames']):
                    x,y=(i%row['columns'])*row['frame_width'],(i//row['columns'])*row['frame_height']
                    frame=atlas.crop((x,y,x+row['frame_width'],y+row['frame_height']))
                    packed.paste(frame,((i%columns)*row['frame_width'],(i//columns)*row['frame_height']))
                packed.save(source,optimize=True,compress_level=9)
            row['columns']=columns
            row['rows']=math.ceil(row['frames']/columns)
        origin=json.dumps(dict(origin=jobs[row['actor'],row['direction']]['source'],weapon=jobs[row['actor'],row['direction']].get('weapon_source',''),scale=jobs[row['actor'],row['direction']]['scale'],animation=row['source_animation'],conversion='Original Spine root and roleScale, offline 30 Hz, not AI generated'),ensure_ascii=True)
        with Image.open(source) as image:
            if image.info.get('impeccable:prompt') != origin:
                info=PngInfo()
                info.add_text('impeccable:prompt', origin)
                image.save(source, pnginfo=info, optimize=True, compress_level=9)
        runtime=ROOT/f'assets/runtime/heroes/{row["id"]}.png'
        runtime.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,runtime)
        aid='heroes.'+row['id']
        large=source.stat().st_size > 8388608 or row['frame_width']*row['columns']>4096 or row['frame_height']*row['rows']>4096
        bindings.append(dict(id=aid,asset_kind='texture_2d',source_path=source.relative_to(ROOT).as_posix(),runtime_path='res://'+runtime.relative_to(ROOT).as_posix(),policy_id='actor_atlas' if large else 'town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
        assets[aid]=dict(sha256=hashlib.sha256(source.read_bytes()).hexdigest(),source_animation=row['source_animation'])
    ui=read_json(ROOT/'art_source/heroes/ui_sources.json')
    for name,record in ui.items():
        source=ROOT/f'art_source/heroes/ui/{name}.png'
        runtime=ROOT/f'assets/runtime/heroes/ui/{name}.png'
        runtime.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,runtime)
        # Sidecars preserve the extracted UI image's exact original bytes.
        for path in [source,runtime]:
            write_json(path.with_suffix('.png.json'),dict(prompt='Original extracted game UI: '+record['source']))
        bindings.append(dict(id='heroes.ui_'+name,asset_kind='texture_2d',source_path=source.relative_to(ROOT).as_posix(),runtime_path='res://'+runtime.relative_to(ROOT).as_posix(),policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))
    for row in rows:
        if row['action']=='idle' and row['direction']=='front' and jobs[row['actor'],row['direction']]['skin']:
            source=ROOT/f'art_source/heroes/{row["actor"]}_portrait.png'
            with Image.open(ROOT/f'art_source/heroes/{row["id"]}.png') as image:
                info=PngInfo();info.add_text('impeccable:prompt',image.info['impeccable:prompt'])
                image.crop((0,0,row['frame_width'],row['frame_height'])).save(source,pnginfo=info)
            register_extra(bindings,source,'heroes.'+row['actor']+'_portrait')
    for source in sorted((ROOT/'art_source/heroes/fx').glob('*.png')):
        register_extra(bindings,source,'heroes.fx_'+source.stem)
    write_csv(ROOT/'data/source/resource_bindings.csv',bindings)
    write_json(ROOT/'art_source/heroes/animations.json',rows)
    write_csv(ROOT/'data/source/town/town_animations.csv',[dict(id=r['id'],actor=r['actor'],direction=r['direction'],action=r['action'],resource_id='heroes.'+r['id'],frames=r['frames'],seconds=r['seconds'],**{n:r[n] for n in ['columns','rows','frame_width','frame_height','origin_y']},variant=r['variant'],source_animation=r['source_animation']) for r in rows])
    write_json(ROOT/'art_source/heroes/provenance.json',dict(jobs=read_json(ROOT/'art_source/heroes/bake_jobs.json'),assets=assets,ui=ui,conversion='PixiJS 7.4.3 / pixi-spine 4.0.6, 30 Hz, full action bounds with 12px padding, original source parts'))
    print('Registered',len(rows),'actor animation sheets')


def register_extra(bindings,source,aid):
    runtime=ROOT/'assets/runtime/heroes'/source.relative_to(ROOT/'art_source/heroes')
    runtime.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,runtime)
    bindings.append(dict(id=aid,asset_kind='texture_2d',source_path=source.relative_to(ROOT).as_posix(),runtime_path='res://'+runtime.relative_to(ROOT).as_posix(),policy_id='town_texture',budget_group='town',owner='prototype_team',license_id='third_party',required='true',consumer='town'))


if __name__=='__main__':main()
