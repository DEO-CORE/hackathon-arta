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


class OrganizationKind(StrEnum):
    """Side of the marketplace; the source of side-specific permissions (api.md 20.12)."""

    supplier = "supplier"
    buyer = "buyer"


class OrgRole(StrEnum):
    OWNER = "OWNER"
    MANAGER = "MANAGER"
    MEMBER = "MEMBER"


class MembershipStatus(StrEnum):
    active = "active"
    # Legacy organization whose side could not be derived: no rights until a platform admin
    # reviews it (docs/api.md 20.12).
    pending_review = "pending_review"
    suspended = "suspended"
    removed = "removed"
