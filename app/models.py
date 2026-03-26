from sqlalchemy import Column, String, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime
import enum
from app.database import Base


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
    target_date = Column(DateTime, nullable=True)
    description = Column(String, nullable=True)
    comment = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
