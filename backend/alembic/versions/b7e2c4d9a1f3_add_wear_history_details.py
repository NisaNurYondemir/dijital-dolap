"""add wear history details

Revision ID: b7e2c4d9a1f3
Revises: a17a46cb66ee
Create Date: 2026-10-25 14:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7e2c4d9a1f3'
down_revision: Union[str, Sequence[str], None] = 'a17a46cb66ee'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Giyim geçmişine puan/amaç/parça bazlı kayıt ekler."""
    # 1) Yeni alanlar
    op.add_column('wear_history', sa.Column('rating', sa.Integer(), nullable=True))
    op.add_column('wear_history', sa.Column('occasion', sa.String(), nullable=True))
    op.add_column('wear_history', sa.Column('note', sa.String(), nullable=True))
    op.add_column('wear_history', sa.Column('weather_temp', sa.Float(), nullable=True))
    op.add_column('wear_history', sa.Column('weather_condition', sa.String(), nullable=True))
    op.add_column('wear_history', sa.Column('location', sa.String(), nullable=True))
    op.add_column(
        'wear_history',
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=True,
        ),
    )

    # 2) Kombin silinince geçmiş korunsun (outfit_id nullable + SET NULL)
    op.alter_column('wear_history', 'outfit_id', existing_type=sa.Integer(), nullable=True)
    op.drop_constraint('wear_history_outfit_id_fkey', 'wear_history', type_='foreignkey')
    op.create_foreign_key(
        'wear_history_outfit_id_fkey',
        'wear_history',
        'outfits',
        ['outfit_id'],
        ['id'],
        ondelete='SET NULL',
    )

    # 3) Puan 1-5 aralığında olsun
    op.create_check_constraint(
        'ck_wear_history_rating',
        'wear_history',
        'rating IS NULL OR (rating BETWEEN 1 AND 5)',
    )
    op.create_index('ix_wear_history_worn_at', 'wear_history', ['worn_at'])

    # 4) Parça bazlı kayıt tablosu
    op.create_table(
        'wear_items',
        sa.Column('wear_id', sa.Integer(), nullable=False),
        sa.Column('clothing_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['wear_id'], ['wear_history.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['clothing_id'], ['clothes.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('wear_id', 'clothing_id'),
    )

    # 5) Eski kayıtları kombinlerindeki parçalarla doldur
    op.execute(
        """
        INSERT INTO wear_items (wear_id, clothing_id)
        SELECT wh.id, oi.clothing_id
        FROM wear_history wh
        JOIN outfit_items oi ON oi.outfit_id = wh.outfit_id
        ON CONFLICT DO NOTHING
        """
    )


def downgrade() -> None:
    """Değişiklikleri geri alır."""
    op.drop_table('wear_items')
    op.drop_index('ix_wear_history_worn_at', table_name='wear_history')
    op.drop_constraint('ck_wear_history_rating', 'wear_history', type_='check')

    op.drop_constraint('wear_history_outfit_id_fkey', 'wear_history', type_='foreignkey')
    op.create_foreign_key(
        'wear_history_outfit_id_fkey',
        'wear_history',
        'outfits',
        ['outfit_id'],
        ['id'],
    )
    op.alter_column('wear_history', 'outfit_id', existing_type=sa.Integer(), nullable=False)

    op.drop_column('wear_history', 'created_at')
    op.drop_column('wear_history', 'location')
    op.drop_column('wear_history', 'weather_condition')
    op.drop_column('wear_history', 'weather_temp')
    op.drop_column('wear_history', 'note')
    op.drop_column('wear_history', 'occasion')
    op.drop_column('wear_history', 'rating')
