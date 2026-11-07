"""Permission matrix (docs/api.md 20.12). Rights come from organization role and side only."""

from app.models.enums import OrganizationKind, OrgRole

S = OrganizationKind.supplier
B = OrganizationKind.buyer
M, MG, OWN = OrgRole.MEMBER, OrgRole.MANAGER, OrgRole.OWNER

_RANK = {OrgRole.MEMBER: 0, OrgRole.MANAGER: 1, OrgRole.OWNER: 2}

# permission -> (minimum organization role, allowed organization sides; None = both)
MATRIX: dict[str, tuple[OrgRole, frozenset[OrganizationKind] | None]] = {
    "org.read": (M, None),
    "org.update": (MG, None),
    "members.manage": (OWN, None),
    "material.read": (M, frozenset({S})),
    "catalog.read": (M, frozenset({B})),
    "material.draft": (M, frozenset({S})),
    "material.edit_published": (MG, frozenset({S})),
    "material.confirm": (M, frozenset({S})),
    "material.publish": (MG, frozenset({S})),
    "material.archive": (MG, frozenset({S})),
    "material.internal_use": (MG, frozenset({S})),
    "ai.analyze": (M, frozenset({S})),
    "planning.read": (M, frozenset({S})),
    # Approved A20-13: planning only proposes an allocation and never reserves or changes stock.
    "planning.run": (M, frozenset({S})),
    "requirement.read_public": (M, frozenset({S})),
    "requirement.read": (M, frozenset({B})),
    "requirement.write": (MG, frozenset({B})),
    "reservation.read": (M, None),
    "reservation.approve": (MG, frozenset({S})),
    "reservation.create": (M, frozenset({B})),
    "reservation.receive": (M, frozenset({B})),
    # Reserved for the buyer-side matching request; no route exists yet.
    "match.request": (M, frozenset({B})),
    "reuse.confirm": (MG, frozenset({B})),
    "analytics.read": (MG, None),
}


# Granted only to buyer organizations specialised as recycler, on top of all buyer rights.
RECYCLER_ONLY: dict[str, OrgRole] = {"recycling.operate": OrgRole.MANAGER}


def permissions_for(
    role: OrgRole, kind: OrganizationKind | None, activity_type: str | None = None
) -> frozenset[str]:
    """Rights derive only from a confirmed organization kind; unknown kind means no rights."""
    if kind is None:
        return frozenset()
    perms = {
        name
        for name, (min_role, kinds) in MATRIX.items()
        if _RANK[role] >= _RANK[min_role] and (kinds is None or kind in kinds)
    }
    if kind == B and activity_type == "recycler":
        perms |= {n for n, r in RECYCLER_ONLY.items() if _RANK[role] >= _RANK[r]}
    return frozenset(perms)
