# Task Management API - Test Scripts

This directory contains shell scripts to test the Task Management API endpoints.

## Prerequisites

- The API must be running (use `docker-compose up` from the project root)
- `curl` command-line tool
- `python3` for JSON formatting (optional but recommended)

## Test Scripts

### Automated Test Suite

**test_api.sh** - Comprehensive automated test suite that tests all API endpoints

```bash
chmod +x test_api.sh
./test_api.sh
```

This script will:
- Test all CRUD operations
- Test filtering and pagination
- Test error handling
- Provide a summary of passed/failed tests

### Manual Test Scripts

#### 1. Create a Task

```bash
chmod +x create_task.sh
./create_task.sh [creator] [assignee] [status] [description] [target_date] [comment]
```

**Example:**
```bash
./create_task.sh "john@example.com" "jane@example.com" "todo" "Implement feature X" "2026-02-15T10:00:00" "High priority"
```

**Defaults:**
- creator: admin@example.com
- assignee: user@example.com
- status: todo
- description: "New task created from script"
- target_date: 2026-02-15T10:00:00
- comment: (empty)

#### 2. List Tasks

```bash
chmod +x list_tasks.sh
./list_tasks.sh [OPTIONS]
```

**Options:**
- `--assignee EMAIL` - Filter by assignee
- `--status STATUS` - Filter by status (todo, inprogress, blocked, done, cancelled)
- `--page-size N` - Number of results per page (default: 20)
- `--offset N` - Offset for pagination (default: 0)

**Examples:**
```bash
# List all tasks
./list_tasks.sh

# List tasks assigned to a specific user
./list_tasks.sh --assignee jane@example.com

# List tasks with status 'todo'
./list_tasks.sh --status todo

# List tasks with pagination
./list_tasks.sh --page-size 10 --offset 0

# Combine filters
./list_tasks.sh --assignee jane@example.com --status inprogress --page-size 5
```

#### 3. Get a Specific Task

```bash
chmod +x get_task.sh
./get_task.sh <task-id>
```

**Example:**
```bash
./get_task.sh 9c69f278-679c-4a09-bafd-43763d10b220
```

#### 4. Update a Task

```bash
chmod +x update_task.sh
./update_task.sh <task-id> [OPTIONS]
```

**Options:**
- `--status STATUS` - Update status
- `--assignee EMAIL` - Update assignee
- `--comment COMMENT` - Update comment
- `--description DESCRIPTION` - Update description

**Examples:**
```bash
# Update task status
./update_task.sh <task-id> --status inprogress

# Update multiple fields
./update_task.sh <task-id> --status done --comment "Task completed"

# Change assignee
./update_task.sh <task-id> --assignee newuser@example.com
```

#### 5. Delete a Task

```bash
chmod +x delete_task.sh
./delete_task.sh <task-id>
```

**Example:**
```bash
./delete_task.sh 9c69f278-679c-4a09-bafd-43763d10b220
```

## Making Scripts Executable

To make all scripts executable at once:

```bash
chmod +x *.sh
```

## Status Values

Valid status values for tasks:
- `todo` - Task is pending
- `inprogress` - Task is being worked on
- `blocked` - Task is blocked
- `done` - Task is completed
- `cancelled` - Task is cancelled

## API Documentation

For interactive API documentation, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Troubleshooting

### Connection Refused Error

If you get a "Connection refused" error, make sure the API is running:

```bash
docker-compose ps
```

If the containers are not running, start them:

```bash
docker-compose up -d
```

### JSON Formatting Not Working

If JSON formatting doesn't work, make sure you have Python 3 installed:

```bash
python3 --version
```

Alternatively, you can remove the `| python3 -m json.tool` part from the scripts to see raw JSON output.

## Example Workflow

```bash
# 1. Run the automated test suite
./test_api.sh

# 2. Create a new task
./create_task.sh "alice@example.com" "bob@example.com" "todo" "Review PR #123"

# 3. List all tasks
./list_tasks.sh

# 4. Get the task ID from the output and update it
./update_task.sh <task-id> --status inprogress --comment "Started review"

# 5. Mark it as done
./update_task.sh <task-id> --status done --comment "Review completed"

# 6. Delete the task
./delete_task.sh <task-id>
```
