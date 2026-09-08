from fastapi import FastAPI, Depends, HTTPException, Query, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
from typing import Optional
from uuid import UUID, uuid4
from app.database import get_db, engine
from app.models import Task, Base, TaskStatus, utcnow
from app.schemas import (
    TaskCreate,
    TaskUpdate,
    TaskResponse,
    TaskListResponse,
    ErrorResponse,
)
from app.config import get_settings
from app.auth import require_scope, SCOPE_READ, SCOPE_WRITE

settings = get_settings()

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Task management API",
    openapi_tags=[
        {
            "name": "Tasks",
            "description": (
                "Operations related to task management. Tasks represent work "
                "items that can be assigned, tracked, and managed through "
                "various workflow states."
            ),
        }
    ],
)

# Reusable error responses so every task tool documents the same failure shapes.
ERROR_400 = {
    "model": ErrorResponse,
    "description": "Bad request - invalid input or query parameters",
}
ERROR_401 = {"model": ErrorResponse, "description": "Unauthorized - missing or invalid token"}
ERROR_403 = {"model": ErrorResponse, "description": "Forbidden - token missing required scope"}
ERROR_404 = {"model": ErrorResponse, "description": "Task not found"}
ERROR_422 = {"model": ErrorResponse, "description": "Validation error"}
ERROR_500 = {"model": ErrorResponse, "description": "Internal server error"}

# Default machine-readable error code per HTTP status.
_STATUS_CODE_MAP = {
    400: "INVALID_PARAMETER",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    422: "VALIDATION_ERROR",
    500: "INTERNAL_ERROR",
}


def _error_payload(status_code: int, message: str, code: Optional[str] = None) -> dict:
    """Build a body matching the ErrorResponse schema."""
    payload = ErrorResponse(
        errorId=uuid4(),
        timestamp=utcnow(),
        code=code or _STATUS_CODE_MAP.get(status_code, "INTERNAL_ERROR"),
        message=message,
    )
    return jsonable_encoder(payload)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Render HTTPExceptions using the ErrorResponse schema.

    A route may raise HTTPException(detail=...) with either a plain string
    message or a dict {"code": ..., "message": ...} to override the code.
    """
    detail = exc.detail
    if isinstance(detail, dict):
        message = detail.get("message", "")
        code = detail.get("code")
    else:
        message = str(detail)
        code = None
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(exc.status_code, message, code),
        headers=getattr(exc, "headers", None),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Render request validation failures using the ErrorResponse schema."""
    errors = exc.errors()
    if errors:
        first = errors[0]
        loc = ".".join(str(p) for p in first.get("loc", []) if p != "body")
        message = f"{loc}: {first.get('msg')}" if loc else first.get("msg", "Validation error")
    else:
        message = "Validation error"
    return JSONResponse(
        status_code=422,
        content=_error_payload(422, message, "VALIDATION_ERROR"),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """Catch-all so unexpected errors still match the ErrorResponse schema."""
    return JSONResponse(
        status_code=500,
        content=_error_payload(500, "An unexpected error occurred.", "INTERNAL_ERROR"),
    )


def _serialize_task(task: Task) -> dict:
    """Convert an ORM Task into the response payload shape."""
    return {
        "id": task.id,
        "creator": task.creator,
        "assignee": task.assignee,
        "status": task.status,
        "targetDate": task.target_date,
        "description": task.description,
        "comment": task.comment,
        "createdAt": task.created_at,
        "updatedAt": task.updated_at,
    }


@app.get("/", include_in_schema=False)
def read_root():
    return {"message": "Task Management API", "version": settings.app_version}


@app.get(
    "/tasks",
    response_model=TaskListResponse,
    operation_id="listTasks",
    summary="List all tasks",
    description=(
        "Retrieves a list of tasks with optional filtering and pagination. "
        "Filter by `assignee` email and/or `status`, and control pagination "
        "with `pageSize` and `offset`. Returns an object with the matching "
        "tasks under the `tasks` property."
    ),
    tags=["Tasks"],
    responses={
        400: ERROR_400,
        401: ERROR_401,
        403: ERROR_403,
        422: ERROR_422,
        500: ERROR_500,
    },
    dependencies=[Depends(require_scope(SCOPE_READ))],
)
def retrieve_list_tasks(
    assignee: Optional[str] = Query(
        None, description="Filter tasks by assignee email address."
    ),
    status: Optional[TaskStatus] = Query(
        None, description="Filter tasks by their current workflow status."
    ),
    pageSize: int = Query(
        20, ge=1, le=100, description="Number of tasks to return per page (max 100)."
    ),
    offset: int = Query(
        0, ge=0, description="Number of tasks to skip before returning results."
    ),
    db: Session = Depends(get_db),
):
    """Retrieve a list of tasks with optional filtering and pagination"""
    query = db.query(Task)

    if assignee:
        query = query.filter(Task.assignee == assignee)

    if status:
        query = query.filter(Task.status == status)

    tasks = query.offset(offset).limit(pageSize).all()

    return {"tasks": [_serialize_task(task) for task in tasks]}


@app.post(
    "/tasks",
    response_model=TaskResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createTask",
    summary="Create a new task",
    description=(
        "Creates a new task. `description` is required; all other fields are "
        "optional. The task `id`, `createdAt`, and `updatedAt` are generated "
        "by the server. Returns the created task."
    ),
    tags=["Tasks"],
    responses={
        400: ERROR_400,
        401: ERROR_401,
        403: ERROR_403,
        422: ERROR_422,
        500: ERROR_500,
    },
    dependencies=[Depends(require_scope(SCOPE_WRITE))],
)
def create_new_task(task: TaskCreate, db: Session = Depends(get_db)):
    """Create a new task"""
    db_task = Task(
        creator=task.creator,
        assignee=task.assignee,
        status=task.status,
        target_date=task.targetDate,
        description=task.description,
        comment=task.comment,
    )

    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    return _serialize_task(db_task)


@app.get(
    "/tasks/{taskId}",
    response_model=TaskResponse,
    operation_id="getTaskById",
    summary="Get a task by ID",
    description=(
        "Retrieves a single task by its unique identifier (UUID). Returns the "
        "complete task object including all fields and timestamps."
    ),
    tags=["Tasks"],
    responses={
        400: ERROR_400,
        401: ERROR_401,
        403: ERROR_403,
        404: ERROR_404,
        422: ERROR_422,
        500: ERROR_500,
    },
    dependencies=[Depends(require_scope(SCOPE_READ))],
)
def retrieve_task_id(taskId: UUID, db: Session = Depends(get_db)):
    """Retrieve a task by ID"""
    task = db.query(Task).filter(Task.id == taskId).first()

    if not task:
        raise HTTPException(
            status_code=404,
            detail={"code": "NOT_FOUND", "message": f"Task with ID {taskId} not found"},
        )

    return _serialize_task(task)


@app.put(
    "/tasks/{taskId}",
    response_model=TaskResponse,
    operation_id="updateTask",
    summary="Update a task",
    description=(
        "Updates an existing task. All fields are optional; only the fields "
        "provided are modified. `id`, `creator`, `createdAt`, and `updatedAt` "
        "cannot be modified. Returns the updated task."
    ),
    tags=["Tasks"],
    responses={
        400: ERROR_400,
        401: ERROR_401,
        403: ERROR_403,
        404: ERROR_404,
        422: ERROR_422,
        500: ERROR_500,
    },
    dependencies=[Depends(require_scope(SCOPE_WRITE))],
)
def update_task_id(
    taskId: UUID, task_update: TaskUpdate, db: Session = Depends(get_db)
):
    """Update a task by ID"""
    task = db.query(Task).filter(Task.id == taskId).first()

    if not task:
        raise HTTPException(
            status_code=404,
            detail={"code": "NOT_FOUND", "message": f"Task with ID {taskId} not found"},
        )

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

    task.updated_at = utcnow()

    db.commit()
    db.refresh(task)

    return _serialize_task(task)


@app.delete(
    "/tasks/{taskId}",
    status_code=status.HTTP_204_NO_CONTENT,
    operation_id="deleteTask",
    summary="Delete a task",
    description=(
        "Permanently deletes a task by its unique identifier (UUID). This "
        "operation cannot be undone and returns no content on success."
    ),
    tags=["Tasks"],
    responses={
        400: ERROR_400,
        401: ERROR_401,
        403: ERROR_403,
        404: ERROR_404,
        422: ERROR_422,
        500: ERROR_500,
    },
    dependencies=[Depends(require_scope(SCOPE_WRITE))],
)
def delete_task_id(taskId: UUID, db: Session = Depends(get_db)):
    """Delete a task by ID"""
    task = db.query(Task).filter(Task.id == taskId).first()

    if not task:
        raise HTTPException(
            status_code=404,
            detail={"code": "NOT_FOUND", "message": f"Task with ID {taskId} not found"},
        )

    db.delete(task)
    db.commit()

    return None


def custom_openapi():
    """Generated OpenAPI, adjusted so that 422 responses advertise the same
    ErrorResponse schema the runtime actually returns (FastAPI otherwise
    injects its default HTTPValidationError)."""
    if app.openapi_schema:
        return app.openapi_schema

    from fastapi.openapi.utils import get_openapi

    schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
        tags=app.openapi_tags,
    )

    error_ref = {"$ref": "#/components/schemas/ErrorResponse"}
    for path in schema.get("paths", {}).values():
        for operation in path.values():
            resp_422 = operation.get("responses", {}).get("422")
            if resp_422:
                content = resp_422.get("content", {}).get("application/json")
                if content and content.get("schema", {}).get("$ref", "").endswith(
                    "HTTPValidationError"
                ):
                    content["schema"] = error_ref

    # Drop the now-unused default validation schemas.
    for name in ("HTTPValidationError", "ValidationError"):
        schema.get("components", {}).get("schemas", {}).pop(name, None)

    # Document the two accepted auth methods: JWT bearer, or HTTP Basic auth.
    security_schemes = schema.setdefault("components", {}).setdefault("securitySchemes", {})
    security_schemes["bearerAuth"] = {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
        "description": (
            "Access token issued by the configured external IdP. Required scopes: "
            "`tasks:read` for GET calls, `tasks:write` for POST/PUT/DELETE calls."
        ),
    }
    security_schemes["basicAuth"] = {
        "type": "http",
        "scheme": "basic",
        "description": (
            "Static credentials (configured via the BASIC_AUTH_USERNAME and "
            "BASIC_AUTH_PASSWORD environment variables). Grants the admin "
            "role: both scopes (full access)."
        ),
    }
    schema["security"] = [{"bearerAuth": []}, {"basicAuth": []}]

    app.openapi_schema = schema
    return schema


app.openapi = custom_openapi
