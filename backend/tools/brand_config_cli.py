#!/usr/bin/env python3
"""Small, fail-closed CLI for Studio-00 BrandConfig and local brand assets.

It deliberately does not provide a Studio UI, signed upload URLs, focal editing,
or any promise that native candidates update an installed app.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any
from xml.sax.saxutils import escape

from pydantic import ValidationError

BACKEND_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = BACKEND_ROOT.parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.schemas.brand_config import validate_brand_config


DEFAULT_ASSETS_ROOT = BACKEND_ROOT / "assets" / "brands"
DEFAULT_BUNDLE_ROOT = REPOSITORY_ROOT / "frontend" / "assets" / "branding"


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"config: {error}") from error
    if not isinstance(value, dict):
        raise ValueError("config: expected a JSON object")
    return value


def _field_errors(error: ValidationError) -> list[dict[str, str]]:
    return [
        {"field": ".".join(str(part) for part in issue["loc"]), "message": issue["msg"]}
        for issue in error.errors()
    ]


def load_validated_config(path: Path) -> dict[str, Any]:
    try:
        return validate_brand_config(_load_json(path))
    except ValidationError as error:
        raise ValueError(json.dumps({"valid": False, "errors": _field_errors(error)}, ensure_ascii=False)) from error


def _write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _avatar_dimensions(path: Path) -> tuple[int, int]:
    """Read image dimensions with Pillow, which is already a backend dependency."""
    try:
        from PIL import Image

        with Image.open(path) as image:
            return image.size
    except ImportError as error:  # pragma: no cover - dependency is pinned in dev env
        raise ValueError("avatar: Pillow is required for image validation") from error
    except OSError as error:
        raise ValueError(f"avatar: unsupported or corrupt image ({error})") from error


def copy_avatar(source: Path, tenant_slug: str, assets_root: Path) -> Path:
    if source.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
        raise ValueError("avatar: expected PNG, JPEG, or WebP")
    width, height = _avatar_dimensions(source)
    if (width, height) != (512, 512):
        raise ValueError(f"avatar: expected exactly 512x512 pixels, got {width}x{height}")
    # Normalize the staged object to PNG, so the PENDING runtime URL and the
    # artifact extension always describe the actual bytes.
    from PIL import Image

    destination = assets_root / tenant_slug / "avatar-512.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image.convert("RGBA").save(destination, format="PNG")
    return destination


def _monogram_svg(config: dict[str, Any], size: int, label: str) -> str:
    brand = config["brand"]
    accent = brand["accent"]
    pressed = brand["derived"]["accentPressed"]
    glyph = escape(brand["creatorName"].strip()[0].upper())
    name = escape(brand["name"])
    radius = size // 2
    font_size = round(size * 0.43)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}" role="img" aria-label="{name} {label}">
  <defs><linearGradient id="background" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{accent}"/><stop offset="1" stop-color="{pressed}"/></linearGradient></defs>
  <rect width="{size}" height="{size}" rx="{radius}" fill="url(#background)"/>
  <circle cx="{radius}" cy="{radius}" r="{round(size * .415)}" fill="none" stroke="#F5EEE1" stroke-opacity=".45" stroke-width="{max(2, size // 128)}"/>
  <text x="{radius}" y="{round(size * .60)}" fill="#FFFFFF" font-family="Georgia, serif" font-size="{font_size}" font-weight="700" text-anchor="middle">{glyph}</text>
</svg>
'''


def generate_candidates(config: dict[str, Any], output_dir: Path) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    generated = {
        "monogram-512.svg": _monogram_svg(config, 512, "monogram"),
        "icon-candidate.svg": _monogram_svg(config, 1024, "native icon candidate"),
        "splash-candidate.svg": _monogram_svg(config, 2048, "native splash candidate"),
        "favicon-candidate.svg": _monogram_svg(config, 512, "favicon candidate"),
    }
    paths = []
    for name, content in generated.items():
        path = output_dir / name
        path.write_text(content, encoding="utf-8")
        paths.append(path)
    (output_dir / "README.md").write_text(
        "# Generated native asset candidates\n\n"
        "These are build/release inputs only. An installed mobile app cannot receive icon or splash changes through runtime BrandConfig. "
        "Review, rasterize to platform-specific sizes, and ship them through the native release pipeline.\n",
        encoding="utf-8",
    )
    return paths


def build_bundle(config: dict[str, Any], tenant_id: str, product_config: dict[str, Any], output: Path) -> None:
    _write_json(output, {
        "tenant": {"id": tenant_id, "slug": config["tenantSlug"]},
        "brandConfig": config,
        "productConfig": product_config,
        "configVersion": "bundled-studio-0",
    })


def _rpc(name: str, params: dict[str, Any]) -> list[dict[str, Any]]:
    # Import lazily: validate/dry-run and asset generation must work offline
    # and must not initialize a Supabase client.
    from app.services.database import SupabaseService

    result = SupabaseService().get_client(use_service_key=True).rpc(name, params).execute()
    return result.data or []


def command_validate(args: argparse.Namespace) -> int:
    config = load_validated_config(args.config)
    print(json.dumps({"valid": True, "tenantSlug": config["tenantSlug"], "config": config}, ensure_ascii=False, indent=2))
    return 0


def command_publish(args: argparse.Namespace) -> int:
    config = load_validated_config(args.config)
    result = {"tenantSlug": config["tenantSlug"], "dryRun": args.dry_run, "valid": True}
    if not args.dry_run:
        rows = _rpc("publish_brand_config", {"p_tenant_slug": config["tenantSlug"], "p_config": config, "p_created_by": args.created_by})
        result["published"] = rows[0] if rows else None
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def command_rollback(args: argparse.Namespace) -> int:
    result = {"tenantSlug": args.tenant_slug, "sourceVersion": args.version, "dryRun": args.dry_run}
    if not args.dry_run:
        rows = _rpc("rollback_brand_config", {"p_tenant_slug": args.tenant_slug, "p_version": args.version})
        result["published"] = rows[0] if rows else None
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def command_avatar(args: argparse.Namespace) -> int:
    destination = copy_avatar(args.source, args.tenant_slug, args.assets_root)
    print(json.dumps({"tenantSlug": args.tenant_slug, "asset": str(destination), "runtimeUrl": f"PENDING:/brands/{args.tenant_slug}/avatar-512.png"}, ensure_ascii=False))
    return 0


def command_candidates(args: argparse.Namespace) -> int:
    config = load_validated_config(args.config)
    output = args.output_dir or DEFAULT_ASSETS_ROOT / config["tenantSlug"] / "candidates"
    paths = generate_candidates(config, output)
    print(json.dumps({"tenantSlug": config["tenantSlug"], "candidates": [str(path) for path in paths]}, ensure_ascii=False, indent=2))
    return 0


def command_bundle(args: argparse.Namespace) -> int:
    config = load_validated_config(args.config)
    product_config = _load_json(args.product_config) if args.product_config else {}
    output = args.output or DEFAULT_BUNDLE_ROOT / f'{config["tenantSlug"]}_bootstrap.json'
    build_bundle(config, args.tenant_id, product_config, output)
    print(json.dumps({"tenantSlug": config["tenantSlug"], "bundle": str(output)}, ensure_ascii=False))
    return 0


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(description=__doc__)
    commands = cli.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate", help="validate a BrandConfig and print field errors")
    validate.add_argument("--config", type=Path, required=True)
    validate.set_defaults(handler=command_validate)
    publish = commands.add_parser("publish", help="publish a new immutable BrandConfig version")
    publish.add_argument("--config", type=Path, required=True)
    publish.add_argument("--created-by", default=None)
    publish.add_argument("--dry-run", action="store_true")
    publish.set_defaults(handler=command_publish)
    rollback = commands.add_parser("rollback", help="republish a historical config as a new version")
    rollback.add_argument("--tenant-slug", required=True)
    rollback.add_argument("--version", type=int, required=True)
    rollback.add_argument("--dry-run", action="store_true")
    rollback.set_defaults(handler=command_rollback)
    avatar = commands.add_parser("avatar", help="validate and stage a 512x512 avatar asset")
    avatar.add_argument("--tenant-slug", required=True)
    avatar.add_argument("--source", type=Path, required=True)
    avatar.add_argument("--assets-root", type=Path, default=DEFAULT_ASSETS_ROOT)
    avatar.set_defaults(handler=command_avatar)
    candidates = commands.add_parser("candidates", help="generate monogram/native asset candidates")
    candidates.add_argument("--config", type=Path, required=True)
    candidates.add_argument("--output-dir", type=Path)
    candidates.set_defaults(handler=command_candidates)
    bundle = commands.add_parser("bundle", help="write a validated bundled tenant bootstrap artifact")
    bundle.add_argument("--config", type=Path, required=True)
    bundle.add_argument("--tenant-id", required=True)
    bundle.add_argument("--product-config", type=Path)
    bundle.add_argument("--output", type=Path)
    bundle.set_defaults(handler=command_bundle)
    return cli


def main() -> int:
    args = parser().parse_args()
    try:
        return args.handler(args)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2
    except Exception as error:
        print(f"studio command failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
