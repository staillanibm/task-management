#!/bin/bash

# Script to get a task by ID

BASE_URL="http://localhost:8000"

if [ -z "$1" ]; then
    echo "Usage: $0 <task-id>"
    exit 1
fi

TASK_ID="$1"

echo "Fetching task: $TASK_ID"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/tasks/$TASK_ID")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "$BODY" | python3 -m json.tool
elif [ "$HTTP_CODE" -eq 404 ]; then
    echo "✗ Task not found"
    exit 1
else
    echo "✗ Failed to fetch task (HTTP $HTTP_CODE)"
    echo "$BODY"
    exit 1
fi
