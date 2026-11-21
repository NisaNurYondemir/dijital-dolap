"""Kıyafet paleti ve desen alanları.

- palette: baskın + yan renkler; [{name, hue, saturation, lightness, ratio}]
- pattern: duz/cizgili/ekose/... (pattern_rules.PATTERN_TYPES)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b3c4d5e6f7a8'
down_revision: Union[str, Sequence[str], None] = 'f5a6b7c8d9e0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('clothes', sa.Column('palette', sa.JSON(), nullable=True))
    op.add_column('clothes', sa.Column('pattern', sa.String(length=20), nullable=True))
    op.add_column('clothes', sa.Column('pattern_scale', sa.String(length=20), nullable=True))
    op.add_column('clothes', sa.Column('pattern_source', sa.String(length=20), nullable=True))
    op.add_column('clothes', sa.Column('pattern_confidence', sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column('clothes', 'pattern_confidence')
    op.drop_column('clothes', 'pattern_source')
    op.drop_column('clothes', 'pattern_scale')
    op.drop_column('clothes', 'pattern')
    op.drop_column('clothes', 'palette')
