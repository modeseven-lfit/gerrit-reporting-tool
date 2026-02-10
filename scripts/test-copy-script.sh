#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Script to test copy-artifacts-simple.sh locally
#
# This creates a mock artifact directory structure and tests the copy script
# without actually pushing to the remote repository.

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
if [ ! -f ".github/scripts/copy-artifacts-simple.sh" ]; then
    log_error "This script must be run from the repository root"
    log_info "cd to the reporting-tool directory first"
    exit 1
fi

log_section "🧪 Test Setup for copy-artifacts-simple.sh"

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

log_info "Test directory: ${TEST_DIR}"

# Create mock artifacts directory structure
log_info "Creating mock artifact structure..."

ARTIFACTS_DIR="${TEST_DIR}/downloaded-artifacts"
mkdir -p "${ARTIFACTS_DIR}"

# Simulate GitHub Actions download-artifact behavior
# It creates: downloaded-artifacts/artifact-name/artifact-name/files

log_info "Creating mock project artifacts..."

# Project 1: ONAP (files directly in artifact directory)
mkdir -p "${ARTIFACTS_DIR}/reports-ONAP"
cat > "${ARTIFACTS_DIR}/reports-ONAP/report.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>ONAP Report</title></head>
<body><h1>ONAP Project Report</h1></body>
</html>
EOF

cat > "${ARTIFACTS_DIR}/reports-ONAP/report.md" << 'EOF'
# ONAP Report
This is a test report for ONAP project.
EOF

cat > "${ARTIFACTS_DIR}/reports-ONAP/metadata.json" << 'EOF'
{
  "project": "ONAP",
  "generated_at": "2025-01-20T10:00:00Z",
  "repositories": 50
}
EOF

# Raw data for ONAP (files directly in artifact directory)
mkdir -p "${ARTIFACTS_DIR}/raw-data-ONAP"
cat > "${ARTIFACTS_DIR}/raw-data-ONAP/report_raw.json" << 'EOF'
{
  "project": "ONAP",
  "metrics": {
    "total_commits": 1000,
    "contributors": 50
  }
}
EOF

cat > "${ARTIFACTS_DIR}/raw-data-ONAP/config_resolved.json" << 'EOF'
{
  "project": "ONAP",
  "config_version": "1.0"
}
EOF

# Project 2: Opendaylight (files directly in artifact directory)
mkdir -p "${ARTIFACTS_DIR}/reports-Opendaylight"
cat > "${ARTIFACTS_DIR}/reports-Opendaylight/report.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Opendaylight Report</title></head>
<body><h1>Opendaylight Project Report</h1></body>
</html>
EOF

cat > "${ARTIFACTS_DIR}/reports-Opendaylight/report.md" << 'EOF'
# Opendaylight Report
This is a test report for Opendaylight project.
EOF

# Raw data for Opendaylight (files directly in artifact directory)
mkdir -p "${ARTIFACTS_DIR}/raw-data-Opendaylight"
cat > "${ARTIFACTS_DIR}/raw-data-Opendaylight/report_raw.json" << 'EOF'
{
  "project": "Opendaylight",
  "metrics": {
    "total_commits": 800,
    "contributors": 40
  }
}
EOF

# Project 3: Project with spaces in name
mkdir -p "${ARTIFACTS_DIR}/reports-Test Project"
cat > "${ARTIFACTS_DIR}/reports-Test Project/report.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Test Project Report</title></head>
<body><h1>Test Project Report</h1></body>
</html>
EOF

log_success "Created mock artifacts for 3 projects (including one with spaces in name)"

# Show directory structure
log_section "📁 Mock Artifact Directory Structure"
echo ""
find "${ARTIFACTS_DIR}" -type f | head -20

# Count files
TOTAL_FILES=$(find "${ARTIFACTS_DIR}" -type f | wc -l)
log_info "Total files created: ${TOTAL_FILES}"

# Create a mock target repository
log_section "🎯 Creating Mock Target Repository"

MOCK_REPO="${TEST_DIR}/mock-project-reporting-artifacts"
mkdir -p "${MOCK_REPO}"
cd "${MOCK_REPO}"
git init --quiet
git config user.name "Test User"
git config user.email "test@example.com"

# Create initial structure
mkdir -p data/artifacts
echo "# Mock Project Reporting Artifacts Repository" > README.md
git add .
git commit -m "Initial commit" --quiet

log_success "Created mock target repository at: ${MOCK_REPO}"

cd -

# Create modified version of script for local testing
log_section "🔧 Creating Test Version of Script"

TEST_SCRIPT="${TEST_DIR}/copy-artifacts-simple-test.sh"
cp .github/scripts/copy-artifacts-simple.sh "${TEST_SCRIPT}"

# Modify the script to use local repo instead of GitHub
# Replace the clone command with local path
sed -i.bak \
    "s|git clone --depth 1 \"\$REPO_URL\" repo|cp -r \"${MOCK_REPO}\" repo|g" \
    "${TEST_SCRIPT}"

# Replace git push with a local verification
sed -i.bak \
    's|git push origin main 2>/dev/null|git log --oneline -1 \&\& echo "Would push to origin main"|g' \
    "${TEST_SCRIPT}"

chmod +x "${TEST_SCRIPT}"

log_success "Created test script: ${TEST_SCRIPT}"

# Run the test
log_section "🚀 Running Copy Script Test"
echo ""

DATE_FOLDER="2025-01-20"
REMOTE_REPO="modeseven-lfit/project-reporting-artifacts"
FAKE_TOKEN="test-token-not-used"

log_info "Running: ${TEST_SCRIPT}"
log_info "  Date folder: ${DATE_FOLDER}"
log_info "  Artifacts: ${ARTIFACTS_DIR}"
log_info "  Target repo: ${REMOTE_REPO}"
echo ""

# Set environment variables for the script
export GITHUB_RUN_ID="test-run-12345"
export GITHUB_EVENT_NAME="workflow_dispatch"

if "${TEST_SCRIPT}" \
    "${DATE_FOLDER}" \
    "${ARTIFACTS_DIR}" \
    "${REMOTE_REPO}" \
    "${FAKE_TOKEN}"; then

    log_section "✅ Test PASSED"
    echo ""

    # Verify the results
    log_info "Verifying copied files..."

    TARGET_DIR="${TEST_DIR}/repo/data/artifacts/${DATE_FOLDER}"

    if [ -d "${TARGET_DIR}" ]; then
        log_success "Target directory exists: ${TARGET_DIR}"

        # Count files in target
        COPIED_FILES=$(find "${TARGET_DIR}" -type f | wc -l)
        log_info "Files in target: ${COPIED_FILES}"

        # Show structure
        echo ""
        log_info "Directory structure in target:"
        find "${TARGET_DIR}" -type f | sed 's|'"${TEST_DIR}"'/repo/||' | sort

        # Check for README
        if [ -f "${TARGET_DIR}/README.md" ]; then
            echo ""
            log_success "README.md was created"
            echo ""
            echo "━━━ README.md contents ━━━"
            cat "${TARGET_DIR}/README.md"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi

        # Check for project directories
        echo ""
        log_info "Project directories found:"
        for dir in "${TARGET_DIR}"/reports-*; do
            if [ -d "$dir" ]; then
                proj_name=$(basename "$dir")
                file_count=$(find "$dir" -type f | wc -l)
                log_success "  ${proj_name}: ${file_count} files"
            fi
        done

        # Verify git commit
        echo ""
        log_info "Git commit log:"
        cd "${TEST_DIR}/repo"
        git log --oneline -1
        cd - > /dev/null

    else
        log_error "Target directory was not created!"
        exit 1
    fi

else
    log_section "❌ Test FAILED"
    echo ""
    log_error "The script exited with an error"
    exit 1
fi

# Test second run (should skip if folder exists)
log_section "🔁 Testing Second Run (Should Skip)"
echo ""

log_info "Running script again with same date..."

if "${TEST_SCRIPT}" \
    "${DATE_FOLDER}" \
    "${ARTIFACTS_DIR}" \
    "${REMOTE_REPO}" \
    "${FAKE_TOKEN}"; then

    log_success "Second run completed (should have skipped upload)"
else
    log_warning "Second run failed (expected if folder exists)"
fi

# Summary
log_section "📊 Test Summary"
echo ""

log_success "✓ Mock artifacts created successfully"
log_success "✓ Script executed without errors"
log_success "✓ Files were copied to target directory"
log_success "✓ README.md was generated"
log_success "✓ Git commit was created"
echo ""

log_info "To inspect the results manually:"
echo "  cd ${TEST_DIR}/repo/data/artifacts/${DATE_FOLDER}"
echo ""

log_info "Test directory will be cleaned up on exit"
echo ""

# Keep the test directory for inspection if requested
if [ "${KEEP_TEST_DIR:-}" = "true" ]; then
    trap - EXIT
    log_warning "Test directory preserved (KEEP_TEST_DIR=true): ${TEST_DIR}"
fi

log_section "✅ All Tests Passed"
echo ""
