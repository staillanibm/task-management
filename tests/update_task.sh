#!/bin/bash

# Script to update a task

BASE_URL="http://localhost:8000"

if [ -z "$1" ]; then
    echo "Usage: $0 <task-id> [--status STATUS] [--assignee EMAIL] [--comment COMMENT]"
    echo "Status values: todo, inprogress, blocked, done, cancelled"
    exit 1
fi

TASK_ID="$1"
shift

# Parse optional arguments
UPDATE_DATA="{"
FIRST=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --status)
            if [ "$FIRST" = false ]; then UPDATE_DATA="${UPDATE_DATA},"; fi
            UPDATE_DATA="${UPDATE_DATA}\"status\":\"$2\""
            FIRST=false
            shift 2
            ;;
        --assignee)
            if [ "$FIRST" = false ]; then UPDATE_DATA="${UPDATE_DATA},"; fi
            UPDATE_DATA="${UPDATE_DATA}\"assignee\":\"$2\""
            FIRST=false
            shift 2
            ;;
        --comment)
            if [ "$FIRST" = false ]; then UPDATE_DATA="${UPDATE_DATA},"; fi
            UPDATE_DATA="${UPDATE_DATA}\"comment\":\"$2\""
            FIRST=false
            shift 2
            ;;
        --description)
            if [ "$FIRST" = false ]; then UPDATE_DATA="${UPDATE_DATA},"; fi
            UPDATE_DATA="${UPDATE_DATA}\"description\":\"$2\""
            FIRST=false
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

UPDATE_DATA="${UPDATE_DATA}}"

echo "Updating task: $TASK_ID"
echo "Update data: $UPDATE_DATA"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/tasks/$TASK_ID" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_DATA")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✓ Task updated successfully!"
    echo ""
    echo "$BODY" | python3 -m json.tool
elif [ "$HTTP_CODE" -eq 404 ]; then
    echo "✗ Task not found"
    exit 1
else
    echo "✗ Failed to update task (HTTP $HTTP_CODE)"
    echo "$BODY"
    exit 1
fi
