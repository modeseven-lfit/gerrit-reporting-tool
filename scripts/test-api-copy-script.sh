#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Script to test copy-api.sh locally
#
# This creates mock artifacts and tests the GitHub API upload script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$*${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if we're in the right directory
if [ ! -f ".github/scripts/copy-api.sh" ]; then
    log_error "This script must be run from the repository root"
    log_info "cd to the reporting-tool directory first"
    exit 1
fi

# Check for required tools
log_section "🔧 Checking Dependencies"

MISSING_DEPS=0

if ! command -v jq &> /dev/null; then
    log_error "jq is not installed"
    log_info "Install with: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    MISSING_DEPS=1
fi

if ! command -v curl &> /dev/null; then
    log_error "curl is not installed"
    MISSING_DEPS=1
fi

if ! command -v base64 &> /dev/null; then
    log_error "base64 is not installed"
    MISSING_DEPS=1
fi

if [ $MISSING_DEPS -eq 1 ]; then
    exit 1
fi

log_success "All dependencies installed"

# Check for GitHub token
log_section "🔑 Checking GitHub Token"

if [ -z "${GERRIT_REPORTS_PAT_TOKEN:-}" ]; then
    log_error "GERRIT_REPORTS_PAT_TOKEN environment variable is not set"
    echo ""
    echo "Please set your GitHub PAT token:"
    echo "  export GERRIT_REPORTS_PAT_TOKEN=github_pat_xxxxxxxxxxxxx"
    echo ""
    echo "The token needs:"
    echo "  - Repository access to: modeseven-lfit/project-reporting-artifacts"
    echo "  - Contents: Read and write"
    echo "  - Metadata: Read-only"
    exit 1
fi

log_success "Token is set (${GERRIT_REPORTS_PAT_TOKEN:0:15}...)"

# Test GitHub API access
log_section "🧪 Testing GitHub API Access"

log_info "Testing API authentication..."

API_TEST=$(curl -s -H "Authorization: Bearer ${GERRIT_REPORTS_PAT_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user)

if echo "$API_TEST" | jq -e '.login' > /dev/null 2>&1; then
    USERNAME=$(echo "$API_TEST" | jq -r '.login')
    log_success "Authenticated as: ${USERNAME}"
else
    log_error "Failed to authenticate with GitHub API"
    echo "$API_TEST"
    exit 1
fi

log_info "Testing repository access..."

REPO_TEST=$(curl -s -H "Authorization: Bearer ${GERRIT_REPORTS_PAT_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/modeseven-lfit/project-reporting-artifacts)

if echo "$REPO_TEST" | jq -e '.id' > /dev/null 2>&1; then
    REPO_NAME=$(echo "$REPO_TEST" | jq -r '.full_name')
    log_success "Can access repository: ${REPO_NAME}"
else
    log_error "Cannot access modeseven-lfit/project-reporting-artifacts repository"
    echo "$REPO_TEST" | jq '.message' 2>/dev/null || echo "$REPO_TEST"
    exit 1
fi

# Check write permissions by testing if we can get repo permissions
PERMS=$(echo "$REPO_TEST" | jq -r '.permissions.push // false')
if [ "$PERMS" = "true" ]; then
    log_success "Token has write access to repository"
else
    log_warning "Cannot verify write access - this may fail during upload"
fi

# Create test artifacts
log_section "📦 Creating Test Artifacts"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

log_info "Test directory: ${TEST_DIR}"

ARTIFACTS_DIR="${TEST_DIR}/test-artifacts"
mkdir -p "${ARTIFACTS_DIR}"

# Create small test artifacts (we'll only upload a few files for testing)
log_info "Creating test project artifacts..."

# Project 1: TestProject
mkdir -p "${ARTIFACTS_DIR}/reports-TestProject"
cat > "${ARTIFACTS_DIR}/reports-TestProject/report.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Test Report</title></head>
<body><h1>Test Project Report - API Upload Test</h1></body>
</html>
EOF

cat > "${ARTIFACTS_DIR}/reports-TestProject/metadata.json" << 'EOF'
{
  "project": "TestProject",
  "generated_at": "2025-01-20T10:00:00Z",
  "test": true
}
EOF

# Raw data for TestProject
mkdir -p "${ARTIFACTS_DIR}/raw-data-TestProject"
cat > "${ARTIFACTS_DIR}/raw-data-TestProject/report_raw.json" << 'EOF'
{
  "project": "TestProject",
  "metrics": {
    "total_commits": 100,
    "contributors": 10
  },
  "test": true
}
EOF

log_success "Created test artifacts"

# Show what we created
log_info "Test artifact structure:"
find "${ARTIFACTS_DIR}" -type f

TOTAL_FILES=$(find "${ARTIFACTS_DIR}" -type f | wc -l | tr -d ' ')
log_info "Total test files: ${TOTAL_FILES}"

# Generate test date folder (use YYYY-MM-DD format as required by script)
TEST_DATE="$(date +%Y-%m-%d)"
log_section "🚀 Running API Upload Script"

log_info "Test date folder: ${TEST_DATE}"
log_info "Target: modeseven-lfit/project-reporting-artifacts"
log_info "Path: data/artifacts/${TEST_DATE}/"
echo ""

log_warning "This will create REAL files in the project-reporting-artifacts repository!"
log_warning "Files will be uploaded to: data/artifacts/${TEST_DATE}/"
echo ""

read -p "Continue with test upload? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    log_info "Test cancelled"
    exit 0
fi

# Set environment variables for the script
GITHUB_RUN_ID="test-local-$(date +%s)"
export GITHUB_RUN_ID
export GITHUB_EVENT_NAME="manual-test"

# Run the script
log_info "Executing copy-api.sh..."
echo ""

if ./.github/scripts/copy-api.sh \
    "${TEST_DATE}" \
    "${ARTIFACTS_DIR}" \
    "modeseven-lfit/project-reporting-artifacts" \
    "${GERRIT_REPORTS_PAT_TOKEN}"; then

    log_section "✅ Test PASSED"
    echo ""
    log_success "Script executed successfully!"
    log_success "Files uploaded: ${TOTAL_FILES}"
    echo ""
    log_info "View uploaded files at:"
    echo "  https://github.com/modeseven-lfit/project-reporting-artifacts/tree/main/data/artifacts/${TEST_DATE}"
    echo ""

    # Test verification - try to fetch the README we created
    log_section "🔍 Verifying Upload"

    log_info "Checking if README.md was created..."

    README_CHECK=$(curl -s -H "Authorization: Bearer ${GERRIT_REPORTS_PAT_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/modeseven-lfit/project-reporting-artifacts/contents/data/artifacts/${TEST_DATE}/README.md")

    if echo "$README_CHECK" | jq -e '.sha' > /dev/null 2>&1; then
        log_success "README.md exists in repository!"

        # Decode and show first few lines
        CONTENT=$(echo "$README_CHECK" | jq -r '.content' | base64 -d)
        echo ""
        log_info "README.md content (first 10 lines):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$CONTENT" | head -10
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_warning "Could not verify README.md"
    fi

    echo ""
    log_section "🧹 Cleanup"

    log_warning "The test files are now in the project-reporting-artifacts repository"
    log_info "Location: data/artifacts/${TEST_DATE}/"
    echo ""

    read -p "Delete test folder from repository? (yes/no): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        log_info "Deleting test folder via API..."

        # Get all files in the test folder
        TREE_URL="https://api.github.com/repos/modeseven-lfit/project-reporting-artifacts/git/trees/main:data/artifacts/${TEST_DATE}?recursive=1"
        TREE=$(curl -s -H "Authorization: Bearer ${GERRIT_REPORTS_PAT_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            "$TREE_URL")

        if echo "$TREE" | jq -e '.tree' > /dev/null 2>&1; then
            # Note: GitHub API doesn't have a "delete folder" endpoint
            # You'd need to delete each file individually or use git operations
            log_warning "Automatic deletion not implemented (GitHub API limitation)"
            log_info "To clean up, manually delete the folder at:"
            echo "  https://github.com/modeseven-lfit/project-reporting-artifacts/tree/main/data/artifacts/${TEST_DATE}"
        fi
    else
        log_info "Test files left in repository"
        log_info "You can delete them manually if needed"
    fi

    echo ""
    log_section "✅ Test Complete"
    echo ""

else
    log_section "❌ Test FAILED"
    echo ""
    log_error "Script execution failed"
    log_info "Check the error messages above for details"
    exit 1
fi
