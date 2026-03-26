from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID
from app.models import TaskStatus


class TaskBase(BaseModel):
    creator: Optional[str] = None
    assignee: Optional[str] = None
    status: Optional[TaskStatus] = TaskStatus.TODO
    targetDate: Optional[datetime] = Field(None, alias="targetDate")
    description: Optional[str] = None
    comment: Optional[str] = None


class TaskCreate(TaskBase):
    pass


class TaskUpdate(TaskBase):
    pass


class TaskResponse(TaskBase):
    id: UUID
    createdAt: datetime = Field(alias="createdAt")
    updatedAt: datetime = Field(alias="updatedAt")

    class Config:
        from_attributes = True
        populate_by_name = True


class ErrorResponse(BaseModel):
    errorId: UUID = Field(default_factory=lambda: UUID(int=0))
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    code: str
    message: str
