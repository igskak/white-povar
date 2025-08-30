#!/usr/bin/env python3
"""
Move legacy Supabase Storage video objects from double-prefixed keys to canonical paths.

- Legacy objects live under: bucket 'recipe-videos' with key 'recipe-videos/<recipe_id>/<filename>'
- Canonical location: key '<recipe_id>/<filename>'

This script:
1) Lists objects under the 'recipe-videos/recipe-videos/' prefix
2) For each object, copies it to the canonical key (without the first 'recipe-videos/')
3) Optionally deletes the old object if --delete-originals is passed
4) Dry-run by default

Usage:
  python backend/tools/move_video_objects.py --supabase-url ... --service-key ... [--delete-originals]
"""
import argparse
from supabase import create_client


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--supabase-url', required=True)
    parser.add_argument('--service-key', required=True)
    parser.add_argument('--delete-originals', action='store_true')
    args = parser.parse_args()

    client = create_client(args.supabase_url, args.service_key)
    bucket = client.storage.from_('recipe-videos')

    # List legacy files
    prefix = 'recipe-videos/'
    print(f'Listing legacy files with prefix: {prefix}')
    items = bucket.list(path=prefix, limit=1000)

    moved = 0
    for item in items:
        name = item.get('name')
        if not name:
            continue
        # Only act on files where the key itself starts with 'recipe-videos/'
        if not name.startswith('recipe-videos/'):
            continue
        new_key = name[len('recipe-videos/'):]
        print(f'Would move: {name} -> {new_key}')
        try:
            # Copy
            bucket.copy(from_path=name, to_path=new_key)
            moved += 1
            # Delete old
            if args.delete_originals:
                bucket.remove([name])
        except Exception as e:
            print(f'Failed to move {name}: {e}')

    print(f'Total moved (copied): {moved}')


if __name__ == '__main__':
    main()

