#!/usr/bin/env python3
"""Internal-only demo entitlement operations; there is no public reset route.

Uses server credentials from ``backend/.env``.  It deliberately prints user
IDs and entitlement state, not email addresses or purchase payloads.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))
load_dotenv(BACKEND_ROOT / '.env')

from app.services.database import supabase_service  # noqa: E402


def _tenant_id(slug: str) -> str:
    result = supabase_service.get_client(True).table('chefs').select('id').eq('slug', slug).limit(1).execute()
    if not result.data:
        raise ValueError('tenant not found')
    return str(result.data[0]['id'])


def _user_id(email: str) -> str:
    result = supabase_service.get_client(True).table('users').select('id').ilike('email', email).limit(1).execute()
    if not result.data:
        raise ValueError('user not found')
    return str(result.data[0]['id'])


def command_list(args: argparse.Namespace) -> None:
    tenant_id = _tenant_id(args.tenant)
    query = supabase_service.get_client(True).table('commerce_entitlements').select(
        'id,user_id,scope_type,collection_id,status,expires_at,source,created_at'
    ).eq('chef_id', tenant_id).eq('source', 'demo')
    if args.email:
        query = query.eq('user_id', _user_id(args.email))
    print(json.dumps(query.execute().data or [], ensure_ascii=False, indent=2, default=str))


def command_grant(args: argparse.Namespace) -> None:
    result = supabase_service.get_client(True).rpc('issue_demo_purchase', {
        'p_user_id': _user_id(args.email), 'p_chef_id': _tenant_id(args.tenant),
        'p_offer_key': args.offer_key, 'p_idempotency_key': f'internal-grant-{uuid4()}',
    }).execute()
    payload = result.data
    if isinstance(payload, list):
        payload = payload[0] if payload else {}
    print(json.dumps(payload or {}, ensure_ascii=False, default=str))


def command_revoke(args: argparse.Namespace) -> None:
    result = supabase_service.get_client(True).table('commerce_entitlements').update({'status': 'revoked'}).eq(
        'chef_id', _tenant_id(args.tenant)
    ).eq('user_id', _user_id(args.email)).eq('source', 'demo').neq('status', 'revoked').execute()
    print(json.dumps({'revoked': len(result.data or [])}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for name, handler in (('list', command_list), ('grant', command_grant), ('revoke', command_revoke), ('reset', command_revoke)):
        command = commands.add_parser(name)
        command.add_argument('--tenant', required=True)
        if name == 'list':
            command.add_argument('--email')
        else:
            command.add_argument('--email', required=True)
        if name == 'grant':
            command.add_argument('--offer-key', required=True)
        command.set_defaults(handler=handler)
    try:
        args = parser.parse_args()
        args.handler(args)
    except Exception as exc:
        print(f'demo commerce command failed: {exc}', file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == '__main__':
    main()
