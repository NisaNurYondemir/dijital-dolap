"""Kombin isim/açıklama + giyim kaydına sıcaklık geri bildirimi (comfort)."""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f5a6b7c8d9e0'
down_revision: Union[str, Sequence[str], None] = 'd4e5f6a7b8c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('outfits', sa.Column('name', sa.String(length=60), nullable=True))
    op.add_column('outfits', sa.Column('description', sa.String(length=300), nullable=True))
    # -2 çok üşüdüm ... 0 tam ayarında ... +2 çok sıcakladım
    op.add_column('wear_history', sa.Column('comfort', sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column('wear_history', 'comfort')
    op.drop_column('outfits', 'description')
    op.drop_column('outfits', 'name')
