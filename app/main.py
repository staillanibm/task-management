from fastapi import FastAPI, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional, List
from uuid import UUID
from app.database import get_db, engine
from app.models import Task, Base, TaskStatus
from app.schemas import TaskCreate, TaskUpdate, TaskResponse, ErrorResponse
from app.config import get_settings
from datetime import datetime

settings = get_settings()

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Task management API"
)


@app.get("/")
def read_root():
    return {"message": "Task Management API", "version": settings.app_version}


@app.get("/tasks", response_model=List[TaskResponse], tags=["Tasks"])
def retrieve_list_tasks(
    assignee: Optional[str] = Query(None),
    status: Optional[TaskStatus] = Query(None),
    pageSize: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """Retrieve a list of tasks with optional filtering and pagination"""
    query = db.query(Task)

    if assignee:
        query = query.filter(Task.assignee == assignee)

    if status:
        query = query.filter(Task.status == status)

    tasks = query.offset(offset).limit(pageSize).all()

    # Convert to response format
    result = []
    for task in tasks:
        result.append({
            "id": task.id,
            "creator": task.creator,
            "assignee": task.assignee,
            "status": task.status,
            "targetDate": task.target_date,
            "description": task.description,
            "comment": task.comment,
            "createdAt": task.created_at,
            "updatedAt": task.updated_at
        })

    return result


@app.post("/tasks", response_model=TaskResponse, status_code=status.HTTP_201_CREATED, tags=["Tasks"])
def create_new_task(
    task: TaskCreate,
    db: Session = Depends(get_db)
):
    """Create a new task"""
    db_task = Task(
        creator=task.creator,
        assignee=task.assignee,
        status=task.status,
        target_date=task.targetDate,
        description=task.description,
        comment=task.comment
    )

    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    return {
        "id": db_task.id,
        "creator": db_task.creator,
        "assignee": db_task.assignee,
        "status": db_task.status,
        "targetDate": db_task.target_date,
        "description": db_task.description,
        "comment": db_task.comment,
        "createdAt": db_task.created_at,
        "updatedAt": db_task.updated_at
    }


@app.get("/tasks/{taskId}", response_model=TaskResponse, tags=["Tasks"])
def retrieve_task_id(
    taskId: UUID,
    db: Session = Depends(get_db)
):
    """Retrieve a task by ID"""
    task = db.query(Task).filter(Task.id == taskId).first()

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    return {
        "id": task.id,
        "creator": task.creator,
        "assignee": task.assignee,
        "status": task.status,
        "targetDate": task.target_date,
        "description": task.description,
        "comment": task.comment,
        "createdAt": task.created_at,
        "updatedAt": task.updated_at
    }


@app.put("/tasks/{taskId}", response_model=TaskResponse, tags=["Tasks"])
def update_task_id(
    taskId: UUID,
    task_update: TaskUpdate,
    db: Session = Depends(get_db)
):
    """Update a task by ID"""
    task = db.query(Task).filter(Task.id == taskId).first()

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    # Update fields if provided
    if task_update.creator is not None:
        task.creator = task_update.creator
    if task_update.assignee is not None:
        task.assignee = task_update.assignee
    if task_update.status is not None:
        task.status = task_update.status
    if task_update.targetDate is not None:
        task.target_date = task_update.targetDate
    if task_update.description is not None:
        task.description = task_update.description
    if task_update.comment is not None:
        task.comment = task_update.comment

    task.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(task)

    return {
        "id": task.id,
        "creator": task.creator,
        "assignee": task.assignee,
        "status": task.status,
        "targetDate": task.target_date,
        "description": task.description,
        "comment": task.comment,
        "createdAt": task.created_at,
        "updatedAt": task.updated_at
    }


@app.delete("/tasks/{taskId}", status_code=status.HTTP_204_NO_CONTENT, tags=["Tasks"])
def delete_task_id(
    taskId: UUID,
    db: Session = Depends(get_db)
):
    """Delete a task by ID"""
    task = db.query(Task).filter(Task.id == taskId).first()

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    db.delete(task)
    db.commit()

    return None
