from sqlalchemy import Column, String, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime, timezone
import enum
from app.database import Base


def utcnow() -> datetime:
    """Timezone-aware UTC timestamp so values serialize as RFC 3339 (with offset)."""
    return datetime.now(timezone.utc)


def to_utc(value: datetime) -> datetime:
    """Normalize a datetime to timezone-aware UTC.

    Naive datetimes (e.g. values read back from SQLite, which drops tzinfo) are
    assumed to already be UTC; aware datetimes are converted to UTC. This keeps
    serialization consistent (RFC 3339 with offset) regardless of the backend.
    """
    if value is None:
        return value
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class TaskStatus(str, enum.Enum):
    TODO = "todo"
    INPROGRESS = "inprogress"
    BLOCKED = "blocked"
    DONE = "done"
    CANCELLED = "cancelled"


class Task(Base):
    __tablename__ = "tasks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    creator = Column(String, nullable=True)
    assignee = Column(String, nullable=True)
    status = Column(SQLEnum(TaskStatus, values_callable=lambda x: [e.value for e in x]), nullable=True, default=TaskStatus.TODO)
    target_date = Column(DateTime(timezone=True), nullable=True)
    description = Column(String, nullable=True)
    comment = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)
