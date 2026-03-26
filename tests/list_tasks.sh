#!/bin/bash

# Script to list tasks with optional filters

BASE_URL="http://localhost:8000"

# Parse command line arguments
ASSIGNEE=""
STATUS=""
PAGE_SIZE=20
OFFSET=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --assignee)
            ASSIGNEE="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --page-size)
            PAGE_SIZE="$2"
            shift 2
            ;;
        --offset)
            OFFSET="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--assignee EMAIL] [--status STATUS] [--page-size N] [--offset N]"
            echo "Status values: todo, inprogress, blocked, done, cancelled"
            exit 1
            ;;
    esac
done

# Build query string
QUERY="pageSize=$PAGE_SIZE&offset=$OFFSET"
if [ -n "$ASSIGNEE" ]; then
    QUERY="${QUERY}&assignee=$ASSIGNEE"
fi
if [ -n "$STATUS" ]; then
    QUERY="${QUERY}&status=$STATUS"
fi

echo "Fetching tasks..."
if [ -n "$ASSIGNEE" ]; then
    echo "Assignee: $ASSIGNEE"
fi
if [ -n "$STATUS" ]; then
    echo "Status: $STATUS"
fi
echo "Page size: $PAGE_SIZE"
echo "Offset: $OFFSET"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/tasks?$QUERY")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "$BODY" | python3 -m json.tool
else
    echo "✗ Failed to fetch tasks (HTTP $HTTP_CODE)"
    echo "$BODY"
    exit 1
fi
