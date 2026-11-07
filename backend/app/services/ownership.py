"""Organization buyers retain shared ownership; personal buyers are scoped by user ID."""

from app.models.enums import Role


def requirement_scope(model, user):
    return (
        model.organization_id == user.organization_id
        if user.organization_id
        else model.user_id == user.id
    )


def reservation_scope(model, user):
    if user.role == Role.enterprise:
        return model.seller_organization_id == user.organization_id
    return (
        model.buyer_organization_id == user.organization_id
        if user.organization_id
        else model.buyer_user_id == user.id
    )


def owns_requirement(row, user):
    return (
        row.organization_id == user.organization_id
        if user.organization_id
        else row.organization_id is None and row.user_id == user.id
    )


def owns_reservation(row, user):
    if user.role == Role.enterprise:
        return row.seller_organization_id == user.organization_id
    return (
        row.buyer_organization_id == user.organization_id
        if user.organization_id
        else row.buyer_organization_id is None and row.buyer_user_id == user.id
    )
