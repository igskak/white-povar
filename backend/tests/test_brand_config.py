import copy
import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.schemas.brand_config import BrandConfig, derive_brand_colors, validate_brand_config


FIXTURE = Path(__file__).parent / "fixtures" / "ohorodnik-oleksandr.brand-config.json"


def pilot_config():
    return json.loads(FIXTURE.read_text())


def test_pilot_config_is_publishable_and_derives_runtime_tokens():
    config = validate_brand_config(pilot_config())

    assert config["brand"]["derived"] == {
        "accentPressed": "#4B5E70",
        "accentOnDark": "#6B8092",
        "onAccent": "#FFFFFF",
        "lightCtaMode": "accentFill",
    }


@pytest.mark.parametrize(
    ("accent", "expected_pressed", "expected_on_dark", "expected_on_accent", "expected_cta"),
    [
        ("#D9A441", "#BC881B", "#D9A441", "#16130F", "inkFill"),
        ("#3F7D52", "#2B6A40", "#4C8A5E", "#FFFFFF", "accentFill"),
        ("#A64869", "#913557", "#BF5E7E", "#FFFFFF", "accentFill"),
    ],
)
def test_reference_brands_use_oklch_derivation_and_contrast_gates(
    accent, expected_pressed, expected_on_dark, expected_on_accent, expected_cta
):
    derived = derive_brand_colors(accent)

    assert derived["accentPressed"] == expected_pressed
    assert derived["accentOnDark"] == expected_on_dark
    assert derived["onAccent"] == expected_on_accent
    assert derived["lightCtaMode"] == expected_cta


@pytest.mark.parametrize(
    ("path", "value"),
    [
        (("brand", "courseTag"), None),
        (("brand", "voice", "courseName"), None),
    ],
)
def test_course_name_and_tag_are_a_required_pair(path, value):
    config = pilot_config()
    target = config
    for segment in path[:-1]:
        target = target[segment]
    target[path[-1]] = value

    with pytest.raises(ValidationError, match="courseName and courseTag"):
        BrandConfig.model_validate(config)


@pytest.mark.parametrize(
    "mutator, field",
    [
        (lambda config: config["brand"].update(avatar="relative-avatar.png"), "brand.avatar"),
        (lambda config: config["brand"].update(font="script"), "brand.font"),
        (
            lambda config: config["brand"].update(
                heroPhotos=[{"url": "https://assets.example/hero.jpg", "roles": ["banner"]}]
            ),
            "brand.heroPhotos.0.roles.0",
        ),
        (
            lambda config: config["brand"].update(
                heroPhotos=[
                    {"url": "https://assets.example/hero.jpg", "roles": ["home"], "focal": {"x": 1.1}}
                ]
            ),
            "brand.heroPhotos.0.focal.x",
        ),
    ],
)
def test_invalid_urls_font_roles_and_focal_points_have_field_errors(mutator, field):
    config = copy.deepcopy(pilot_config())
    mutator(config)

    with pytest.raises(ValidationError) as error:
        BrandConfig.model_validate(config)

    assert any(".".join(str(part) for part in item["loc"]) == field for item in error.value.errors())


def test_hero_photo_list_is_empty_or_has_between_three_and_six_items():
    config = pilot_config()
    config["brand"]["heroPhotos"] = [
        {"url": f"https://assets.example/hero-{index}.jpg", "roles": ["home"]}
        for index in range(2)
    ]

    with pytest.raises(ValidationError, match="3 to 6"):
        BrandConfig.model_validate(config)
