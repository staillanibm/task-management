#!/bin/bash

# Script to delete a task

BASE_URL="http://localhost:8000"

if [ -z "$1" ]; then
    echo "Usage: $0 <task-id>"
    exit 1
fi

TASK_ID="$1"

echo "Deleting task: $TASK_ID"

RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/tasks/$TASK_ID")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 204 ]; then
    echo "✓ Task deleted successfully!"
elif [ "$HTTP_CODE" -eq 404 ]; then
    echo "✗ Task not found"
    exit 1
else
    echo "✗ Failed to delete task (HTTP $HTTP_CODE)"
    echo "$BODY"
    exit 1
fi
