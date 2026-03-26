#!/bin/bash

# Task Management API Test Script
# This script tests all API endpoints

#BASE_URL="http://localhost:8000"
#BASE_URL="https://task-management-tasks.apps.itz-q037mu.infra01-lb.fra02.techzone.ibm.com"
BASE_URL="https://wmapigateway.apps.itz-q037mu.infra01-lb.fra02.techzone.ibm.com/user-demo-org/wmsandbox/tasks/1.0.0"
PASSED=0
FAILED=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print test results
print_test() {
    local test_name=$1
    local status=$2
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        ((FAILED++))
    fi
}

echo "=================================="
echo "Task Management API Tests"
echo "=================================="
echo ""

# Test 1: Root endpoint
echo "Test 1: GET / - Root endpoint"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL/)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] && echo "$BODY" | grep -q "Task Management API"; then
    print_test "Root endpoint returns 200 and correct message" 0
else
    print_test "Root endpoint returns 200 and correct message" 1
fi
echo ""

# Test 2: List all tasks
echo "Test 2: GET /tasks - List all tasks"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL/tasks)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "List tasks returns 200" 0
else
    print_test "List tasks returns 200" 1
fi
echo ""

# Test 3: Create a new task
echo "Test 3: POST /tasks - Create a new task"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/tasks \
    -H "Content-Type: application/json" \
    -d '{
        "creator": "tester@example.com",
        "assignee": "developer@example.com",
        "status": "todo",
        "description": "Automated test task",
        "targetDate": "2026-02-01T10:00:00",
        "comment": "This is a test"
    }')
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    print_test "Create task returns 201" 0
    # Extract task ID for further tests
    TASK_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Created task ID: $TASK_ID"
else
    print_test "Create task returns 201" 1
    TASK_ID=""
fi
echo ""

# Test 4: Get task by ID
if [ -n "$TASK_ID" ]; then
    echo "Test 4: GET /tasks/{id} - Get task by ID"
    RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL/tasks/$TASK_ID)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_test "Get task by ID returns 200" 0
    else
        print_test "Get task by ID returns 200" 1
    fi
    echo ""
fi

# Test 5: Update task
if [ -n "$TASK_ID" ]; then
    echo "Test 5: PUT /tasks/{id} - Update task"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT $BASE_URL/tasks/$TASK_ID \
        -H "Content-Type: application/json" \
        -d '{
            "status": "inprogress",
            "comment": "Task updated via test"
        }')
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -eq 200 ] && echo "$BODY" | grep -q "inprogress"; then
        print_test "Update task returns 200 and status is updated" 0
    else
        print_test "Update task returns 200 and status is updated" 1
    fi
    echo ""
fi

# Test 6: Filter by status
echo "Test 6: GET /tasks?status=todo - Filter by status"
RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/tasks?status=todo")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "Filter by status returns 200" 0
else
    print_test "Filter by status returns 200" 1
fi
echo ""

# Test 7: Filter by assignee
echo "Test 7: GET /tasks?assignee=developer@example.com - Filter by assignee"
RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/tasks?assignee=developer@example.com")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "Filter by assignee returns 200" 0
else
    print_test "Filter by assignee returns 200" 1
fi
echo ""

# Test 8: Pagination
echo "Test 8: GET /tasks?pageSize=2&offset=0 - Pagination"
RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/tasks?pageSize=2&offset=0")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "Pagination returns 200" 0
else
    print_test "Pagination returns 200" 1
fi
echo ""

# Test 9: Delete task
if [ -n "$TASK_ID" ]; then
    echo "Test 9: DELETE /tasks/{id} - Delete task"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE $BASE_URL/tasks/$TASK_ID)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    if [ "$HTTP_CODE" -eq 204 ]; then
        print_test "Delete task returns 204" 0
    else
        print_test "Delete task returns 204" 1
    fi
    echo ""
fi

# Test 10: Verify task was deleted (should return 404)
if [ -n "$TASK_ID" ]; then
    echo "Test 10: GET /tasks/{id} - Verify task was deleted"
    RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL/tasks/$TASK_ID)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    if [ "$HTTP_CODE" -eq 404 ]; then
        print_test "Deleted task returns 404" 0
    else
        print_test "Deleted task returns 404" 1
    fi
    echo ""
fi

# Test 11: Invalid UUID format
echo "Test 11: GET /tasks/invalid-uuid - Invalid UUID format"
RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL/tasks/invalid-uuid)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" -eq 422 ]; then
    print_test "Invalid UUID returns 422" 0
else
    print_test "Invalid UUID returns 422" 1
fi
echo ""

# Summary
echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
