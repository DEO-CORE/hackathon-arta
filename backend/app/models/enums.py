from enum import StrEnum


class Role(StrEnum):
    enterprise = "enterprise"
    buyer = "buyer"
    admin = "admin"


class RegisterRole(StrEnum):
    enterprise = "enterprise"
    buyer = "buyer"


class ActivityType(StrEnum):
    garment_factory = "garment_factory"
    workshop = "workshop"
    recycler = "recycler"
    other = "other"


class MaterialType(StrEnum):
    cotton = "cotton"
    wool = "wool"
    linen = "linen"
    silk = "silk"
    synthetic = "synthetic"
    knit = "knit"
    denim = "denim"
    mixed = "mixed"
    other = "other"


class MaterialCondition(StrEnum):
    unused = "unused"
    good = "good"
    worn = "worn"
    damaged = "damaged"


class MaterialStatus(StrEnum):
    draft = "draft"
    available = "available"
    reserved = "reserved"
    partially_allocated = "partially_allocated"
    completed = "completed"
    archived = "archived"
