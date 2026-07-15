"""Validated, publishable BrandConfig payloads.

Derived colour tokens are deliberately calculated here, at the boundary where a
draft becomes runtime configuration.  Consumers must never derive branding
colours themselves.
"""

from __future__ import annotations

import math
import re
from enum import Enum
from typing import Literal
from urllib.parse import urlparse

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


INK = "#16130F"
LIGHT_SURFACE = "#F5EEE1"
_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_CYRILLIC = re.compile(r"[\u0400-\u04FF]")


class BrandFont(str, Enum):
    serif = "serif"
    grotesque = "grotesque"
    humanist = "humanist"


class HeroRole(str, Enum):
    home = "home"
    login = "login"
    paywall = "paywall"
    collection = "collection"


def _validate_url(value: str | None) -> str | None:
    if value is None:
        return value
    if value.startswith("PENDING:/brands/"):
        return value
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("must be an absolute https/http URL or approved PENDING asset URL")
    return value


class FocalPoint(BaseModel):
    model_config = ConfigDict(extra="forbid")

    x: float = Field(default=0.5, ge=0, le=1)
    y: float = Field(default=0.4, ge=0, le=1)


class HeroPhoto(BaseModel):
    model_config = ConfigDict(extra="forbid")

    url: str
    focal: FocalPoint = Field(default_factory=FocalPoint)
    roles: list[HeroRole] = Field(min_length=1)

    _url = field_validator("url")(_validate_url)


class BrandVoice(BaseModel):
    model_config = ConfigDict(extra="forbid")

    greeting: str = Field(min_length=1, max_length=24)
    login_title: str = Field(alias="loginTitle", min_length=1, max_length=28)
    paywall_title: str = Field(alias="paywallTitle", min_length=1, max_length=28)
    course_name: str | None = Field(default=None, alias="courseName", max_length=36)

    @field_validator("greeting", "login_title", "paywall_title", "course_name")
    @classmethod
    def require_cyrillic_copy(cls, value: str | None) -> str | None:
        if value is not None and not _CYRILLIC.search(value):
            raise ValueError("must contain Cyrillic text for the Ukrainian pilot")
        return value


class DerivedBrandColors(BaseModel):
    model_config = ConfigDict(extra="forbid")

    accent_pressed: str = Field(alias="accentPressed")
    accent_on_dark: str = Field(alias="accentOnDark")
    on_accent: Literal["#16130F", "#FFFFFF"] = Field(alias="onAccent")
    light_cta_mode: Literal["accentFill", "inkFill"] = Field(alias="lightCtaMode")


class Brand(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    name: str = Field(min_length=1, max_length=20)
    creator_name: str = Field(alias="creatorName", min_length=1, max_length=16)
    avatar: str
    accent: str
    font: BrandFont = BrandFont.serif
    voice: BrandVoice
    course_tag: str | None = Field(default=None, alias="courseTag")
    hero_photos: list[HeroPhoto] = Field(default_factory=list, alias="heroPhotos", max_length=6)
    logo: str | None = None
    derived: DerivedBrandColors | None = None

    _avatar = field_validator("avatar")(_validate_url)
    _logo = field_validator("logo")(_validate_url)

    @field_validator("accent")
    @classmethod
    def validate_hex(cls, value: str) -> str:
        if not _HEX.fullmatch(value):
            raise ValueError("must be a #RRGGBB colour")
        return value.upper()

    @field_validator("course_tag")
    @classmethod
    def validate_course_tag(cls, value: str | None) -> str | None:
        if value is not None and not _SLUG.fullmatch(value):
            raise ValueError("must be a lowercase URL slug")
        return value

    @model_validator(mode="after")
    def validate_pairs_and_derive(self) -> "Brand":
        if bool(self.voice.course_name) != bool(self.course_tag):
            raise ValueError("voice.courseName and courseTag must be provided together")
        if self.hero_photos and len(self.hero_photos) < 3:
            raise ValueError("heroPhotos must contain 3 to 6 photos when provided")
        self.derived = DerivedBrandColors.model_validate(derive_brand_colors(self.accent))
        return self


class BrandConfig(BaseModel):
    """The complete versioned config that may be published to a tenant."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_version: Literal[1] = Field(alias="schemaVersion")
    tenant_slug: str = Field(alias="tenantSlug", pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    locale: Literal["uk"]
    brand: Brand


def validate_brand_config(config: object) -> dict:
    """Publish gate used by persistence and bootstrap paths."""
    return BrandConfig.model_validate(config).model_dump(by_alias=True)


def derive_brand_colors(accent: str) -> dict[str, str]:
    """Derive sRGB-safe OKLCH tokens specified in implementation plan section 3."""
    lab = _srgb_to_oklab(_hex_to_rgb(accent))
    l, chroma, hue = _oklab_to_oklch(lab)
    pressed = _oklch_to_hex(l * 0.88, chroma, hue)
    accent_on_dark = _lighten_to_contrast(l, chroma, hue, INK, 4.5)
    return {
        "accentPressed": pressed,
        "accentOnDark": accent_on_dark,
        "onAccent": INK if _contrast(accent, INK) >= 4.5 else "#FFFFFF",
        "lightCtaMode": "accentFill" if _contrast(accent, LIGHT_SURFACE) >= 3 else "inkFill",
    }


def _hex_to_rgb(value: str) -> tuple[float, float, float]:
    return tuple(int(value[index:index + 2], 16) / 255 for index in (1, 3, 5))


def _linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def _srgb(value: float) -> float:
    return 12.92 * value if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055


def _srgb_to_oklab(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    r, g, b = (_linear(channel) for channel in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(channel) ** (1 / 3), channel) for channel in (l, m, s))
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def _oklab_to_oklch(lab: tuple[float, float, float]) -> tuple[float, float, float]:
    l, a, b = lab
    return l, math.hypot(a, b), math.atan2(b, a)


def _oklch_to_hex(lightness: float, chroma: float, hue: float) -> str:
    # First reduce chroma to the largest in-gamut value, then round channels.
    low, high = 0.0, chroma
    for _ in range(24):
        candidate = (low + high) / 2
        if _oklch_to_rgb(lightness, candidate, hue) is None:
            high = candidate
        else:
            low = candidate
    rgb = _oklch_to_rgb(lightness, low, hue) or (0.0, 0.0, 0.0)
    return "#" + "".join(f"{round(channel * 255):02X}" for channel in rgb)


def _oklch_to_rgb(lightness: float, chroma: float, hue: float) -> tuple[float, float, float] | None:
    a, b = chroma * math.cos(hue), chroma * math.sin(hue)
    l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
    m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
    s_ = lightness - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    linear = (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )
    rgb = tuple(_srgb(channel) for channel in linear)
    if all(-0.000001 <= channel <= 1.000001 for channel in rgb):
        return tuple(min(1.0, max(0.0, channel)) for channel in rgb)
    return None


def _relative_luminance(value: str) -> float:
    red, green, blue = (_linear(channel) for channel in _hex_to_rgb(value))
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def _contrast(first: str, second: str) -> float:
    lighter, darker = sorted((_relative_luminance(first), _relative_luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def _lighten_to_contrast(lightness: float, chroma: float, hue: float, background: str, minimum: float) -> str:
    original = _oklch_to_hex(lightness, chroma, hue)
    if _contrast(original, background) >= minimum:
        return original
    low, high = lightness, 1.0
    for _ in range(24):
        midpoint = (low + high) / 2
        candidate = _oklch_to_hex(midpoint, chroma, hue)
        if _contrast(candidate, background) >= minimum:
            high = midpoint
        else:
            low = midpoint
    return _oklch_to_hex(high, chroma, hue)
