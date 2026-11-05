#!/usr/bin/env python3
"""Generate idempotent editorial seed inserts for the isolated Toti project."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
seed=json.loads((root/'docs/backend/tods-editorial-seed.json').read_text())
specs={
 'profiles':('editorial_profiles','id text, sort_index integer, name text, country text, image_key text, bio text, region text, doorway text, interests jsonb, age integer','id'),
 'reels':('editorial_reels','id text, original_index integer, display_index integer, author_id text, video_key text, thumbnail_key text, caption text','id'),
 'comments':('editorial_comments','id text, sort_index integer, content_id text, author_id text, body text','id'),
 'rooms':('editorial_rooms','id text, sort_index integer, host_id text, cover_key text, content jsonb','id'),
 'moments':('editorial_moments','id text, sort_index integer, author_id text, image_key text, content jsonb','id'),
 'catalog':('editorial_catalog','category text, sort_index integer, content jsonb','category, sort_index'),
}
statements=[]
for name,(table,types,conflict) in specs.items():
    columns=', '.join(item.strip().split()[0] for item in types.split(','))
    payload=json.dumps(seed[name],ensure_ascii=False,separators=(',',':'))
    assert '$toti_seed$' not in payload
    statements.append(f"insert into public.{table} ({columns}) select {columns} from jsonb_to_recordset($toti_seed${payload}$toti_seed$::jsonb) as rows({types}) on conflict ({conflict}) do nothing;")
out=root/'docs/backend/tods-editorial-seed.sql'
out.write_text('\n'.join(statements)+'\n')
print('Wrote',out.relative_to(root))
