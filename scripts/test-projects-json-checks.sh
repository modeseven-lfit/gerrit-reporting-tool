#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Test script for projects.json validation
# This script tests various scenarios to ensure the validation works correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check-projects-json.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local json_content="$2"
    local should_pass="$3"
    local temp_file

    TESTS_RUN=$((TESTS_RUN + 1))
    temp_file=$(mktemp)
    echo "$json_content" > "$temp_file"

    echo -n "Test ${TESTS_RUN}: ${test_name}... "

    if "$CHECK_SCRIPT" "$temp_file" > /dev/null 2>&1; then
        if [ "$should_pass" = "true" ]; then
            echo -e "${GREEN}PASS${NC} ✓"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} ✗ (should have failed but passed)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        if [ "$should_pass" = "false" ]; then
            echo -e "${GREEN}PASS${NC} ✓"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} ✗ (should have passed but failed)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    fi

    rm -f "$temp_file"
}

echo "=================================="
echo "Projects.json Validation Test Suite"
echo "=================================="
echo ""

# Valid test cases
echo -e "${YELLOW}Valid Configurations:${NC}"

run_test "Valid: Gerrit-only project" \
'[{"project":"Test1","slug":"test1","gerrit":"gerrit.example.org"}]' \
"true"

run_test "Valid: GitHub-only project" \
'[{"project":"Test2","slug":"test2","github":"example-org"}]' \
"true"

run_test "Valid: Gerrit + GitHub project" \
'[{"project":"Test3","slug":"test3","gerrit":"gerrit.example.org","github":"example-org"}]' \
"true"

run_test "Valid: Project with Jenkins" \
'[{"project":"Test4","slug":"test4","github":"example-org","jenkins":"jenkins.example.org"}]' \
"true"

run_test "Valid: Project with Jenkins auth" \
'[{"project":"Test5","slug":"test5","github":"example-org","jenkins":"jenkins.example.org","jenkins_user":"user","jenkins_token":"token123"}]' \
"true"

run_test "Valid: Project with JJB attribution" \
'[{"project":"Test6","slug":"test6","gerrit":"gerrit.example.org","jjb_attribution":{"url":"https://example.org/repo","branch":"master","enabled":true}}]' \
"true"

run_test "Valid: Multiple projects" \
'[{"project":"Test7a","slug":"test7a","gerrit":"gerrit.example.org"},{"project":"Test7b","slug":"test7b","github":"example-org"}]' \
"true"

echo ""
echo -e "${YELLOW}Invalid Configurations:${NC}"

# Invalid test cases
run_test "Invalid: Not an array" \
'{"project":"Test8","slug":"test8","gerrit":"gerrit.example.org"}' \
"false"

run_test "Invalid: Missing project field" \
'[{"slug":"test9","gerrit":"gerrit.example.org"}]' \
"false"

run_test "Invalid: Missing slug field" \
'[{"project":"Test10","gerrit":"gerrit.example.org"}]' \
"false"

run_test "Invalid: Missing both gerrit and github" \
'[{"project":"Test11","slug":"test11","jenkins":"jenkins.example.org"}]' \
"false"

run_test "Valid: Empty project field (jq treats empty strings as truthy)" \
'[{"project":"","slug":"test12","gerrit":"gerrit.example.org"}]' \
"true"

run_test "Valid: Empty slug field (jq treats empty strings as truthy)" \
'[{"project":"Test13","slug":"","gerrit":"gerrit.example.org"}]' \
"true"

run_test "Invalid: Malformed JSON" \
'[{"project":"Test14","slug":"test14","gerrit":"gerrit.example.org"' \
"false"

run_test "Valid: Empty array (technically passes all() check)" \
'[]' \
"true"

echo ""
echo "=================================="
echo -e "${YELLOW}Test Summary:${NC}"
echo "  Total tests run: ${TESTS_RUN}"
echo -e "  ${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "  ${RED}Failed: ${TESTS_FAILED}${NC}"
echo "=================================="

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC} ✓"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC} ✗"
    exit 1
fi
