import importlib.util
import json
from pathlib import Path

import pytest
from PIL import Image


CLI_PATH = Path(__file__).parents[1] / "tools" / "brand_config_cli.py"
FIXTURE = Path(__file__).parent / "fixtures" / "ohorodnik-oleksandr.brand-config.json"


def load_cli_module():
    spec = importlib.util.spec_from_file_location("brand_config_cli", CLI_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_cli_validation_reports_structured_field_errors(tmp_path):
    cli = load_cli_module()
    invalid = json.loads(FIXTURE.read_text())
    invalid["brand"]["accent"] = "blue"
    path = tmp_path / "invalid.json"
    path.write_text(json.dumps(invalid))

    with pytest.raises(ValueError) as error:
        cli.load_validated_config(path)

    payload = json.loads(str(error.value))
    assert payload["valid"] is False
    assert payload["errors"] == [{"field": "brand.accent", "message": "Value error, must be a #RRGGBB colour"}]


def test_publish_dry_run_validates_without_database_access(tmp_path, capsys):
    cli = load_cli_module()
    args = cli.parser().parse_args(["publish", "--config", str(FIXTURE), "--dry-run"])

    assert args.handler(args) == 0

    assert json.loads(capsys.readouterr().out) == {
        "tenantSlug": "ohorodnik-oleksandr", "dryRun": True, "valid": True
    }


def test_bundle_and_generated_candidates_are_tenant_specific(tmp_path):
    cli = load_cli_module()
    config = cli.load_validated_config(FIXTURE)
    bundle = tmp_path / "ohorodnik-oleksandr_bootstrap.json"

    cli.build_bundle(config, "tenant-id", {"locale": "uk", "features": {}}, bundle)
    candidates = cli.generate_candidates(config, tmp_path / "candidates")

    payload = json.loads(bundle.read_text())
    assert payload["tenant"]["slug"] == "ohorodnik-oleksandr"
    assert payload["brandConfig"]["brand"]["derived"] == config["brand"]["derived"]
    assert {path.name for path in candidates} == {
        "monogram-512.svg", "icon-candidate.svg", "splash-candidate.svg", "favicon-candidate.svg"
    }
    assert "runtime BrandConfig" in (tmp_path / "candidates" / "README.md").read_text()


def test_avatar_pipeline_requires_exact_square_512_asset(tmp_path):
    cli = load_cli_module()
    source = tmp_path / "avatar.png"
    Image.new("RGBA", (512, 512), "#5D7183").save(source)

    destination = cli.copy_avatar(source, "ohorodnik-oleksandr", tmp_path / "assets")

    assert destination.suffix == ".png"
    assert cli._avatar_dimensions(destination) == (512, 512)
    wrong_size = tmp_path / "wrong-size.png"
    Image.new("RGBA", (256, 256), "#5D7183").save(wrong_size)
    with pytest.raises(ValueError, match="expected exactly 512x512"):
        cli.copy_avatar(wrong_size, "ohorodnik-oleksandr", tmp_path / "assets")


def test_publish_and_rollback_use_immutable_rpc_contract(monkeypatch):
    cli = load_cli_module()
    calls = []

    def rpc(name, params):
        calls.append((name, params))
        return [{"version": 2, "published_at": "2026-07-15T00:00:00+00:00"}]

    monkeypatch.setattr(cli, "_rpc", rpc)
    publish = cli.parser().parse_args(["publish", "--config", str(FIXTURE)])
    rollback = cli.parser().parse_args([
        "rollback", "--tenant-slug", "ohorodnik-oleksandr", "--version", "1"
    ])

    assert publish.handler(publish) == 0
    assert rollback.handler(rollback) == 0
    assert calls[0][0] == "publish_brand_config"
    assert calls[0][1]["p_config"]["tenantSlug"] == "ohorodnik-oleksandr"
    assert calls[1] == ("rollback_brand_config", {"p_tenant_slug": "ohorodnik-oleksandr", "p_version": 1})
