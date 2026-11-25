"""Amaç gruplarına etkinlik tipi ekler.

Revision ID: d5e6f7a8b9c0
Revises: b3c4d5e6f7a8
Create Date: 2026-11-26
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d5e6f7a8b9c0"
down_revision: Union[str, Sequence[str], None] = "b3c4d5e6f7a8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_TR = str.maketrans("İIıŞşĞğÜüÖöÇç", "iiissgguuoocc")


def _norm(value: str) -> str:
    value = (value or "").translate(_TR).lower()
    for ch in (" ", "-", "_"):
        value = value.replace(ch, "")
    return value.strip()


def _infer(name: str) -> str:
    n = _norm(name)
    if n in {"is", "ofis", "isyeri", "staj", "mulakat", "kariyer"}:
        return "work"
    formal = (
        "dugun", "nisan", "kina", "nikah", "mezuniyet", "ozelgun",
        "abiye", "gala", "davet", "balo", "sunnet", "kokteyl",
    )
    if any(word in n for word in formal):
        return "formal"
    sport = (
        "spor", "antrenman", "kosu", "yoga", "fitness", "tenis",
        "yuzme", "gym", "workout", "pilates", "bisiklet",
    )
    if any(word in n for word in sport):
        return "sport"
    if any(word in n for word in ("romantik", "randevu", "date", "sevgili")):
        return "romantic"
    return "casual"


def upgrade() -> None:
    op.add_column(
        "occasion_groups",
        sa.Column(
            "occasion_type",
            sa.String(length=20),
            nullable=False,
            server_default="casual",
        ),
    )

    bind = op.get_bind()
    rows = bind.execute(
        sa.text("SELECT id, name FROM occasion_groups")
    ).fetchall()
    for group_id, name in rows:
        bind.execute(
            sa.text(
                "UPDATE occasion_groups SET occasion_type = :t WHERE id = :id"
            ),
            {"t": _infer(name), "id": group_id},
        )


def downgrade() -> None:
    op.drop_column("occasion_groups", "occasion_type")
