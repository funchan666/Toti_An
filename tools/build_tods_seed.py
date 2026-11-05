#!/usr/bin/env python3
"""Export existing editorial records without changing the app's source data."""
import ast
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'assets/data/community.json').read_text())
source = (root / 'lib/main.dart').read_text()

def dart_maps(block):
    result = []
    for obj in re.findall(r'\{([^{}]+)\}', block, re.S):
        values = {}
        for key, value in re.findall(r"'([A-Za-z]+)'\s*:\s*(\[[^\]]*\]|'[^']*'|\"[^\"]*\")", obj):
            values[key] = ast.literal_eval(value)
        if values:
            result.append(values)
    return result

rooms = dart_maps(source.split('const roomSeeds = <Map<String, dynamic>>[', 1)[1].split('class Rooms', 1)[0])
moments = dart_maps(source.split('final seed = [', 1)[1].split('final all =', 1)[0])
assert len(rooms) == 6 and len(moments) == 2
assert len(data['images']) <= len(data['names']) and len(data['images']) <= len(data['countries'])

def region(flag):
    groups = {
        'North America': ['🇺🇸','🇨🇦'],
        'Europe': ['🇪🇸','🇩🇪','🇫🇷','🇬🇧','🇮🇹','🇳🇴','🇨🇿','🇳🇱','🇵🇹','🇮🇪','🇮🇸','🇨🇭','🇧🇪'],
        'Asia': ['🇯🇵','🇸🇬','🇰🇷','🇨🇳','🇵🇭'],
        'India': ['🇮🇳'], 'Latin': ['🇧🇷','🇲🇽'], 'MENA': ['🇲🇦'],
        'Africa': ['🇿🇦','🇳🇬'], 'Oceania': ['🇦🇺','🇳🇿'],
    }
    return next((label for label, flags in groups.items() if flag in flags), 'Global')

profiles=[]
for i, image in enumerate(data['images']):
    profiles.append({'id':f'member-{i}','sort_index':i,'name':data['names'][i],
        'country':data['countries'][i],'image_key':'assets/portraits/'+image,
        'bio':data['profileNotes'][i % 12],'region':region(data['countries'][i]),
        'doorway':data['doorways'][i % 6],
        'interests':[data['interestCatalog'][n % len(data['interestCatalog'])] for n in (i,i+3,i+7)],
        'age':22+i%12})
reels=[]
for i, item in enumerate(data['reels']):
    reels.append({'id':'reel:'+item['video'],'original_index':i,
        'display_index':2 if i==0 else 0 if i==2 else i,'author_id':f'member-{i}',
        'video_key':'assets/videos/'+item['video'],'thumbnail_key':'assets/portraits/'+item['thumbnail'],
        'caption':item['caption']})
comments=[{'id':f'comment-{i}','sort_index':i,'content_id':x['content'],'author_id':x['member'],'body':x['text']} for i,x in enumerate(data['reelComments'])]
room_rows=[{'id':x['id'],'sort_index':i,'host_id':'member-'+x['host'],'cover_key':'assets/portraits/'+x['cover'],'content':x} for i,x in enumerate(rooms)]
moment_rows=[{'id':x['id'],'sort_index':i,'author_id':x['member'],'image_key':'assets/portraits/'+x['image'],'content':x} for i,x in enumerate(moments)]
catalog=[{'category':key,'sort_index':i,'content':item} for key,items in data.items() if key not in ('reels','reelComments') for i,item in enumerate(items)]
seed={'profiles':profiles,'reels':reels,'comments':comments,'rooms':room_rows,'moments':moment_rows,'catalog':catalog}
out=root/'docs/backend/tods-editorial-seed.json'
out.write_text(json.dumps(seed,ensure_ascii=False,indent=2)+'\n')
print('Exported', ', '.join(f'{key}={len(value)}' for key,value in seed.items()))
