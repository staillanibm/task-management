#!/bin/bash

# Script to create a new task

BASE_URL="http://localhost:8000"

# Default values
CREATOR="${1:-admin@example.com}"
ASSIGNEE="${2:-user@example.com}"
STATUS="${3:-todo}"
DESCRIPTION="${4:-New task created from script}"
TARGET_DATE="${5:-2026-02-15T10:00:00}"
COMMENT="${6:-}"

echo "Creating new task..."
echo "Creator: $CREATOR"
echo "Assignee: $ASSIGNEE"
echo "Status: $STATUS"
echo "Description: $DESCRIPTION"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/tasks \
    -H "Content-Type: application/json" \
    -d "{
        \"creator\": \"$CREATOR\",
        \"assignee\": \"$ASSIGNEE\",
        \"status\": \"$STATUS\",
        \"description\": \"$DESCRIPTION\",
        \"targetDate\": \"$TARGET_DATE\",
        \"comment\": \"$COMMENT\"
    }")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    echo "✓ Task created successfully!"
    echo ""
    echo "$BODY" | python3 -m json.tool
else
    echo "✗ Failed to create task (HTTP $HTTP_CODE)"
    echo "$BODY"
    exit 1
fi
