# Task Management API

A FastAPI-based task management microservice with PostgreSQL database.

## Features

- RESTful API for task management (CRUD operations)
- PostgreSQL database with automatic schema creation
- Docker containerization
- API filtering and pagination
- UUID-based task identification
- Automatic timestamp management

## Project Structure

```
TaskManagement/
├── app/
│   ├── __init__.py
│   ├── main.py           # FastAPI application and endpoints
│   ├── models.py         # SQLAlchemy database models
│   ├── schemas.py        # Pydantic schemas for validation
│   ├── database.py       # Database connection setup
│   └── config.py         # Configuration management
├── db/
│   └── init.sql          # Database initialization script
├── Dockerfile            # Container definition for the API
├── docker-compose.yml    # Full stack orchestration
├── requirements.txt      # Python dependencies
├── .env.example          # Example environment variables
└── task-management-api.yaml  # OpenAPI specification
```

## Getting Started

### Prerequisites

- Docker
- Docker Compose

### Running the Application

1. Start the complete stack:
```bash
docker-compose up --build
```

This will:
- Start a PostgreSQL database on port 5432
- Run database migrations automatically
- Start the FastAPI application on port 8000

2. Access the API:
- API Base URL: http://localhost:8000
- Interactive API Documentation: http://localhost:8000/docs
- Alternative API Documentation: http://localhost:8000/redoc

### API Endpoints

- `GET /tasks` - Retrieve a list of tasks (with filtering and pagination)
  - Query parameters: `assignee`, `status`, `pageSize`, `offset`
- `POST /tasks` - Create a new task
- `GET /tasks/{taskId}` - Retrieve a specific task
- `PUT /tasks/{taskId}` - Update a task
- `DELETE /tasks/{taskId}` - Delete a task

### Task Status Values

- `todo` - Task is pending
- `inprogress` - Task is being worked on
- `blocked` - Task is blocked
- `done` - Task is completed
- `cancelled` - Task is cancelled

### Example API Calls

Create a task:
```bash
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "creator": "john.doe@example.com",
    "assignee": "jane.smith@example.com",
    "status": "todo",
    "description": "Implement new feature",
    "targetDate": "2026-01-20T10:00:00"
  }'
```

List tasks:
```bash
curl http://localhost:8000/tasks?status=todo&pageSize=10
```

### Development

To run locally without Docker:

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your local database URL
```

4. Run the application:
```bash
uvicorn app.main:app --reload
```

### Stopping the Application

```bash
docker-compose down
```

To remove volumes as well:
```bash
docker-compose down -v
```

## Configuration

Environment variables can be configured in `.env` file:

- `DATABASE_URL` - PostgreSQL connection string
- `APP_NAME` - Application name
- `APP_VERSION` - Application version

## Database Schema

The `tasks` table includes:
- `id` (UUID) - Primary key
- `creator` (String) - Task creator
- `assignee` (String) - Task assignee
- `status` (Enum) - Task status
- `target_date` (DateTime) - Target completion date
- `description` (Text) - Task description
- `comment` (Text) - Additional comments
- `created_at` (DateTime) - Creation timestamp
- `updated_at` (DateTime) - Last update timestamp

Indexes are created on `assignee`, `status`, and `created_at` for optimal query performance.
