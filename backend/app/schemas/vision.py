from typing import Literal

from pydantic import Field, field_validator, model_validator

from app.schemas.commerce import ReuseUse
from app.schemas.types import StrictIn

Confidence = Literal["high", "medium", "low", "unknown"]
Color = Literal[
    "white",
    "black",
    "gray",
    "beige",
    "brown",
    "red",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
    "pink",
    "multicolor",
    "other",
]
Pattern = Literal[
    "solid", "striped", "checked", "floral", "geometric", "printed_other", "mixed", "other"
]
Texture = Literal[
    "smooth",
    "ribbed",
    "woven_looking",
    "knit_looking",
    "fleecy",
    "fuzzy",
    "glossy",
    "rough",
    "other",
]


class SafeModel(StrictIn):
    @field_validator("*", mode="before")
    @classmethod
    def text(cls, v):
        if isinstance(v, str):
            if any(ord(c) < 32 and c not in "\n\t" for c in v):
                raise ValueError("control characters are forbidden")
            return v.strip()
        return v


class ColorObservation(SafeModel):
    primary: Color | None
    secondary: list[Color] = Field(max_length=3)
    description: str | None = Field(max_length=120)
    confidence: Confidence

    @model_validator(mode="after")
    def valid(self):
        if (self.primary is None) != (self.confidence == "unknown"):
            raise ValueError("unknown confidence must have no value")
        if len(self.secondary) != len(set(self.secondary)) or self.primary in self.secondary:
            raise ValueError("duplicate color")
        return self


class Observation(SafeModel):
    value: str | None
    description: str | None = Field(max_length=120)
    confidence: Confidence

    @model_validator(mode="after")
    def valid(self):
        if (self.value is None) != (self.confidence == "unknown"):
            raise ValueError("unknown confidence must have no value")
        return self


class PatternObservation(Observation):
    value: Pattern | None


class TextureObservation(Observation):
    value: Texture | None


class VisualFeatures(SafeModel):
    color: ColorObservation
    pattern: PatternObservation
    apparent_texture: TextureObservation


class ReuseOption(SafeModel):
    reuse_type: ReuseUse
    suitability: Confidence
    reason: str = Field(min_length=10, max_length=300)


class VisionModelOutput(SafeModel):
    visual_features: VisualFeatures
    reuse_options: list[ReuseOption] = Field(max_length=5)
    notes: str | None = Field(max_length=500)

    @model_validator(mode="after")
    def valid(self):
        if len({o.reuse_type for o in self.reuse_options}) != len(self.reuse_options):
            raise ValueError("duplicate reuse type")
        ranks = {"high": 0, "medium": 1, "low": 2, "unknown": 3}
        self.reuse_options.sort(key=lambda o: (ranks[o.suitability], o.reuse_type))
        return self
