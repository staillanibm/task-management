#!/bin/bash

# Task Management API Test Script (API Gateway version)
# This script tests all API endpoints
# Required env vars: APIC_CLIENT_ID, APIC_CLIENT_SECRET
# Optional env vars: BASE_URL (must include version prefix, e.g. .../1.3/v1)

BASE_URL="${BASE_URL:-https://task-management-tasks.apps.itz-kei0ho.infra01-lb.fra02.techzone.ibm.com}"
PASSED=0
FAILED=0

# curl options: skip TLS verification for self-signed gateway certs
CURL_OPTS=(-sk)

# APIC headers
APIC_HEADERS=(-H "x-ibm-client-id: ${APIC_CLIENT_ID}" -H "x-ibm-client-secret: ${APIC_CLIENT_SECRET}")

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check required env vars
if [ -z "$APIC_CLIENT_ID" ] || [ -z "$APIC_CLIENT_SECRET" ]; then
    echo -e "${RED}Error: APIC_CLIENT_ID and APIC_CLIENT_SECRET must be set${NC}"
    exit 1
fi

# Function to print test results
# Usage: print_test <test_name> <pass=0|fail=1> <http_code> [body]
print_test() {
    local test_name=$1
    local status=$2
    local http_code=$3
    local body=$4
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $test_name ${YELLOW}[HTTP $http_code]${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name ${YELLOW}[HTTP $http_code]${NC}"
        if [ -n "$body" ]; then
            echo -e "  ${RED}Response:${NC} $body"
        fi
        ((FAILED++))
    fi
}

echo "=================================="
echo "Task Management API Tests"
echo "=================================="
echo ""

# Test 1: List all tasks
echo "Test 1: GET /tasks - List all tasks"
RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" $BASE_URL/tasks)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "List tasks returns 200" 0 "$HTTP_CODE"
else
    print_test "List tasks returns 200" 1 "$HTTP_CODE" "$BODY"
fi
echo ""

# Test 2: Create a new task
echo "Test 2: POST /tasks - Create a new task"
RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST $BASE_URL/tasks \
    "${APIC_HEADERS[@]}" \
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
    print_test "Create task returns 201" 0 "$HTTP_CODE"
    # Extract task ID for further tests
    TASK_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Created task ID: $TASK_ID"
else
    print_test "Create task returns 201" 1 "$HTTP_CODE" "$BODY"
    TASK_ID=""
fi
echo ""

# Test 3: Get task by ID
if [ -n "$TASK_ID" ]; then
    echo "Test 3: GET /tasks/{id} - Get task by ID"
    RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" $BASE_URL/tasks/$TASK_ID)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_test "Get task by ID returns 200" 0 "$HTTP_CODE"
    else
        print_test "Get task by ID returns 200" 1 "$HTTP_CODE" "$BODY"
    fi
    echo ""
fi

# Test 4: Update task
if [ -n "$TASK_ID" ]; then
    echo "Test 4: PUT /tasks/{id} - Update task"
    RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X PUT $BASE_URL/tasks/$TASK_ID \
        "${APIC_HEADERS[@]}" \
        -H "Content-Type: application/json" \
        -d '{
            "status": "inprogress",
            "comment": "Task updated via test"
        }')
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -eq 200 ] && echo "$BODY" | grep -q "inprogress"; then
        print_test "Update task returns 200 and status is updated" 0 "$HTTP_CODE"
    else
        print_test "Update task returns 200 and status is updated" 1 "$HTTP_CODE" "$BODY"
    fi
    echo ""
fi

# Test 5: Filter by status
echo "Test 5: GET /tasks?status=todo - Filter by status"
RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" "$BASE_URL/tasks?status=todo")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "Filter by status returns 200" 0 "$HTTP_CODE"
else
    print_test "Filter by status returns 200" 1 "$HTTP_CODE" "$BODY"
fi
echo ""

# Test 6: Filter by assignee
echo "Test 6: GET /tasks?assignee=developer@example.com - Filter by assignee"
RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" "$BASE_URL/tasks?assignee=developer@example.com")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "Filter by assignee returns 200" 0 "$HTTP_CODE"
else
    print_test "Filter by assignee returns 200" 1 "$HTTP_CODE" "$BODY"
fi
echo ""

# Test 7: Pagination
echo "Test 7: GET /tasks?pageSize=2&offset=0 - Pagination"
RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" "$BASE_URL/tasks?pageSize=2&offset=0")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    print_test "Pagination returns 200" 0 "$HTTP_CODE"
else
    print_test "Pagination returns 200" 1 "$HTTP_CODE" "$BODY"
fi
echo ""

# Test 8: Delete task
if [ -n "$TASK_ID" ]; then
    echo "Test 8: DELETE /tasks/{id} - Delete task"
    RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X DELETE "${APIC_HEADERS[@]}" $BASE_URL/tasks/$TASK_ID)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -eq 204 ]; then
        print_test "Delete task returns 204" 0 "$HTTP_CODE"
    else
        print_test "Delete task returns 204" 1 "$HTTP_CODE" "$BODY"
    fi
    echo ""
fi

# Test 9: Verify task was deleted (should return 404)
if [ -n "$TASK_ID" ]; then
    echo "Test 9: GET /tasks/{id} - Verify task was deleted"
    RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" $BASE_URL/tasks/$TASK_ID)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -eq 404 ]; then
        print_test "Deleted task returns 404" 0 "$HTTP_CODE"
    else
        print_test "Deleted task returns 404" 1 "$HTTP_CODE" "$BODY"
    fi
    echo ""
fi

# Test 10: Invalid UUID format
echo "Test 10: GET /tasks/invalid-uuid - Invalid UUID format"
RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" "${APIC_HEADERS[@]}" $BASE_URL/tasks/invalid-uuid)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 422 ]; then
    print_test "Invalid UUID returns 422" 0 "$HTTP_CODE"
else
    print_test "Invalid UUID returns 422" 1 "$HTTP_CODE" "$BODY"
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
