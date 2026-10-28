"""add calendar events

Revision ID: e6b9c3d7f210
Revises: c8f3a1d2e4b6
Create Date: 2026-10-28 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e6b9c3d7f210'
down_revision: Union[str, Sequence[str], None] = 'c8f3a1d2e4b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Yaklaşan olaylar için takvim tablosunu ekler."""
    op.create_table(
        'calendar_events',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('kind', sa.String(), nullable=False, server_default='genel'),
        sa.Column('event_date', sa.DateTime(timezone=True), nullable=False),
        sa.Column('occasion_group_id', sa.Integer(), nullable=True),
        sa.Column('note', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['occasion_group_id'], ['occasion_groups.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_calendar_events_id'), 'calendar_events', ['id'])
    op.create_index(op.f('ix_calendar_events_user_id'), 'calendar_events', ['user_id'])
    op.create_index('ix_calendar_events_event_date', 'calendar_events', ['event_date'])


def downgrade() -> None:
    """Takvim tablosunu kaldırır."""
    op.drop_index('ix_calendar_events_event_date', table_name='calendar_events')
    op.drop_index(op.f('ix_calendar_events_user_id'), table_name='calendar_events')
    op.drop_index(op.f('ix_calendar_events_id'), table_name='calendar_events')
    op.drop_table('calendar_events')
