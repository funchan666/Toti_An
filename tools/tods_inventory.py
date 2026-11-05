#!/usr/bin/env python3
"""Create a reproducible, read-only inventory of Toti's bundled content."""
import hashlib
import json
import mimetypes
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
community_path = ROOT / 'assets/data/community.json'
community = json.loads(community_path.read_text(encoding='utf-8'))
references = {}

def reference(path, owner):
    references.setdefault(path, []).append(owner)

for i, name in enumerate(community['images']):
    reference(f'assets/portraits/{name}', f'member-{i}.image')
for i, video in enumerate(community['liveVideos']):
    reference(f'assets/videos/{video}', f'liveVideos[{i}]')
for i, reel in enumerate(community['reels']):
    reference(f"assets/videos/{reel['video']}", f'reels[{i}].video')
    reference(f"assets/portraits/{reel['thumbnail']}", f'reels[{i}].thumbnail')

main_source = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
room_block = main_source.split('const roomSeeds = <Map<String, dynamic>>[', 1)[1].split('class Rooms', 1)[0]
for block in re.findall(r'\{(.*?)\}', room_block, flags=re.S):
    room_id = re.search(r"'id': '([^']+)'", block)
    cover = re.search(r"'cover': '([^']+)'", block)
    if room_id and cover:
        reference(f'assets/portraits/{cover.group(1)}', f'room:{room_id.group(1)}.cover')
for image in re.findall(r"photo\('([^']+)'\)", main_source):
    reference(f'assets/portraits/{image}', 'lib/main.dart literal photo')
for image in re.findall(r"'image': '(moment-stills/[^']+)'", main_source):
    reference(f'assets/portraits/{image}', 'Moments bundled seed')

files = []
for folder in ('assets/portraits', 'assets/videos'):
    for path in sorted((ROOT / folder).rglob('*')):
        if not path.is_file() or path.name.startswith('.'):
            continue
        relative = path.relative_to(ROOT).as_posix()
        digest = hashlib.sha256()
        with path.open('rb') as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b''):
                digest.update(chunk)
        files.append({
            'path': relative,
            'bytes': path.stat().st_size,
            'sha256': digest.hexdigest(),
            'mime': mimetypes.guess_type(path.name)[0] or 'application/octet-stream',
            'community_references': references.get(relative, []),
        })
existing = {item['path'] for item in files}
manifest = {
    'purpose': 'Source inventory only; no upload, deployment, or app integration is implied.',
    'source': 'assets/data/community.json',
    'source_sha256': hashlib.sha256(community_path.read_bytes()).hexdigest(),
    'collections': {key: len(value) for key, value in community.items() if isinstance(value, list)},
    'rendered_member_count': len(community['images']),
    'member_id_rule': 'member-{zero-based image index}',
    'reel_display_order': [2, 1, 0, *range(3, len(community['reels']))] if len(community['reels']) >= 3 else list(range(len(community['reels']))),
    'additional_sources': ['lib/main.dart: roomSeeds', 'lib/main.dart: Moments seed'],
    'missing_community_media': sorted(set(references) - existing),
    'media': files,
}
output = ROOT / 'docs/backend/tods-source-inventory.json'
output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f"Wrote {output.relative_to(ROOT)}: {len(files)} media files, {len(manifest['missing_community_media'])} missing referenced files")
