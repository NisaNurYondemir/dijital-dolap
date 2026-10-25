"""add occasion groups

Revision ID: c8f3a1d2e4b6
Revises: b7e2c4d9a1f3
Create Date: 2026-10-25 15:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c8f3a1d2e4b6'
down_revision: Union[str, Sequence[str], None] = 'b7e2c4d9a1f3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


DEFAULT_OCCASIONS = [
    ("Okul", "🎓", "#4C6FFF"),
    ("İş", "💼", "#22305A"),
    ("Arkadaş", "☕", "#F2B84B"),
    ("Romantik", "❤️", "#E85D75"),
    ("Özel gün", "✨", "#9B51E0"),
    ("Spor", "🏃", "#27AE60"),
    ("Günlük", "🌤️", "#5B6478"),
]


def upgrade() -> None:
    """Kullanıcı tanımlı amaç gruplarını ekler."""
    op.create_table(
        'occasion_groups',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('emoji', sa.String(), nullable=True),
        sa.Column('color', sa.String(), nullable=True),
        sa.Column('is_default', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'name', name='uq_occasion_groups_user_name'),
    )
    op.create_index(op.f('ix_occasion_groups_id'), 'occasion_groups', ['id'])
    op.create_index(op.f('ix_occasion_groups_user_id'), 'occasion_groups', ['user_id'])

    op.create_table(
        'outfit_occasions',
        sa.Column('outfit_id', sa.Integer(), nullable=False),
        sa.Column('occasion_group_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['outfit_id'], ['outfits.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['occasion_group_id'], ['occasion_groups.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('outfit_id', 'occasion_group_id'),
    )

    op.add_column(
        'wear_history',
        sa.Column('occasion_group_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'wear_history_occasion_group_id_fkey',
        'wear_history',
        'occasion_groups',
        ['occasion_group_id'],
        ['id'],
        ondelete='SET NULL',
    )
    op.create_index(
        'ix_wear_history_occasion_group_id',
        'wear_history',
        ['occasion_group_id'],
    )

    # Mevcut kullanıcılara varsayılan grupları ekle
    conn = op.get_bind()
    user_ids = [
        row[0] for row in conn.execute(sa.text('SELECT id FROM users')).fetchall()
    ]
    for user_id in user_ids:
        for name, emoji, color in DEFAULT_OCCASIONS:
            conn.execute(
                sa.text(
                    """
                    INSERT INTO occasion_groups
                        (user_id, name, emoji, color, is_default)
                    VALUES
                        (:user_id, :name, :emoji, :color, true)
                    ON CONFLICT (user_id, name) DO NOTHING
                    """
                ),
                {
                    'user_id': user_id,
                    'name': name,
                    'emoji': emoji,
                    'color': color,
                },
            )

    # Eski serbest metin amaçları gruplara bağla
    rows = conn.execute(
        sa.text(
            """
            SELECT DISTINCT user_id, occasion
            FROM wear_history
            WHERE occasion IS NOT NULL AND btrim(occasion) <> ''
            """
        )
    ).fetchall()
    for user_id, occasion in rows:
        name = occasion.strip()
        group_id = conn.execute(
            sa.text(
                """
                SELECT id FROM occasion_groups
                WHERE user_id = :user_id AND lower(name) = lower(:name)
                """
            ),
            {'user_id': user_id, 'name': name},
        ).scalar()
        if group_id is None:
            group_id = conn.execute(
                sa.text(
                    """
                    INSERT INTO occasion_groups (user_id, name, is_default)
                    VALUES (:user_id, :name, false)
                    RETURNING id
                    """
                ),
                {'user_id': user_id, 'name': name},
            ).scalar()
        conn.execute(
            sa.text(
                """
                UPDATE wear_history
                SET occasion_group_id = :group_id
                WHERE user_id = :user_id AND occasion = :occasion
                """
            ),
            {
                'group_id': group_id,
                'user_id': user_id,
                'occasion': occasion,
            },
        )


def downgrade() -> None:
    """Değişiklikleri geri alır."""
    op.drop_index('ix_wear_history_occasion_group_id', table_name='wear_history')
    op.drop_constraint(
        'wear_history_occasion_group_id_fkey',
        'wear_history',
        type_='foreignkey',
    )
    op.drop_column('wear_history', 'occasion_group_id')
    op.drop_table('outfit_occasions')
    op.drop_index(op.f('ix_occasion_groups_user_id'), table_name='occasion_groups')
    op.drop_index(op.f('ix_occasion_groups_id'), table_name='occasion_groups')
    op.drop_table('occasion_groups')
