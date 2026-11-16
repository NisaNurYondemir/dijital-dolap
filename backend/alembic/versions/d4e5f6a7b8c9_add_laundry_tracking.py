"""Çamaşır takibi: giyilme sayacı ve kullanıcının otomatik kirli kuralları."""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4e5f6a7b8c9'
down_revision: Union[str, Sequence[str], None] = 'e6b9c3d7f210'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'clothes',
        sa.Column('wear_count_since_wash', sa.Integer(), nullable=False,
                  server_default='0'),
    )
    op.add_column('users', sa.Column('laundry_rules', sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'laundry_rules')
    op.drop_column('clothes', 'wear_count_since_wash')
