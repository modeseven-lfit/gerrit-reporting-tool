#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Script to copy report artifacts to the gerrit-reports repository using GitHub API
# This uses the GitHub REST API to create/update files instead of git push
#
# Usage: copy-to-gerrit-reports-api.sh <date-folder> <artifacts-dir> <remote-repo> <token>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${BLUE}ℹ ${NC}$*"
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

# Validate inputs
if [ $# -ne 4 ]; then
    log_error "Usage: $0 <date-folder> <artifacts-dir> <remote-repo> <token>"
    log_error "  date-folder: Date in YYYY-MM-DD format (e.g., 2025-01-20)"
    log_error "  artifacts-dir: Directory containing downloaded artifacts"
    log_error "  remote-repo: Remote repository (e.g., modeseven-lfit/gerrit-reports)"
    log_error "  token: GitHub PAT token for authentication"
    exit 1
fi

DATE_FOLDER="$1"
ARTIFACTS_DIR="$2"
REMOTE_REPO="$3"
GITHUB_TOKEN="$4"

# Validate token is provided
if [ -z "$GITHUB_TOKEN" ]; then
    log_error "GitHub token not provided"
    log_error "Ensure GERRIT_REPORTS_PAT_TOKEN secret is set in repository settings"
    exit 1
fi

# Check token format (should start with ghp_ or github_pat_)
if ! [[ "$GITHUB_TOKEN" =~ ^(ghp_|github_pat_) ]]; then
    log_warning "Token doesn't match expected format (ghp_* or github_pat_*)"
fi

log_info "Token validation: OK (prefix: ${GITHUB_TOKEN:0:10}...)"

# Validate date format
if ! [[ "$DATE_FOLDER" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    log_error "Invalid date format: $DATE_FOLDER (expected YYYY-MM-DD)"
    exit 1
fi

# Validate artifacts directory exists
if [ ! -d "$ARTIFACTS_DIR" ]; then
    log_error "Artifacts directory not found: $ARTIFACTS_DIR"
    exit 1
fi

# Convert artifacts directory to absolute path
ARTIFACTS_DIR=$(cd "$ARTIFACTS_DIR" && pwd)
log_info "Artifacts directory (absolute path): ${ARTIFACTS_DIR}"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    log_info "Install with: apt-get install jq (Ubuntu) or brew install jq (macOS)"
    exit 1
fi

# GitHub API base URL
API_BASE="https://api.github.com"
REPO_API="${API_BASE}/repos/${REMOTE_REPO}"

# Function to make GitHub API call
github_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    if [ -n "$data" ]; then
        curl -s -X "$method" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -d "$data" \
            "${REPO_API}${endpoint}"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "${REPO_API}${endpoint}"
    fi
}

# Function to get file SHA (needed for updates)
get_file_sha() {
    local file_path="$1"
    local response

    response=$(github_api "GET" "/contents/${file_path}" 2>/dev/null || echo "{}")
    echo "$response" | jq -r '.sha // empty' 2>/dev/null || echo ""
}

# Function to create or update a file via GitHub API
upload_file() {
    local local_file="$1"
    local remote_path="$2"

    if [ ! -f "$local_file" ]; then
        log_warning "File not found: $local_file"
        return 1
    fi

    # Get file size
    local file_size
    file_size=$(stat -f%z "$local_file" 2>/dev/null || stat -c%s "$local_file" 2>/dev/null || echo "0")

    # GitHub API has a 100MB limit for content API, skip large files
    if [ "$file_size" -gt 104857600 ]; then
        log_warning "Skipping large file (>100MB): $remote_path"
        return 0
    fi

    # Base64 encode the file content
    local content_base64
    content_base64=$(base64 < "$local_file" | tr -d '\n')

    # Check if file already exists (get its SHA)
    local existing_sha
    existing_sha=$(get_file_sha "$remote_path")

    # Prepare JSON payload
    local message
    if [ -n "$existing_sha" ]; then
        message="Update $remote_path"
    else
        message="Add $remote_path"
    fi

    local json_payload
    if [ -n "$existing_sha" ]; then
        json_payload=$(jq -n \
            --arg msg "$message" \
            --arg content "$content_base64" \
            --arg sha "$existing_sha" \
            '{message: $msg, content: $content, sha: $sha}')
    else
        json_payload=$(jq -n \
            --arg msg "$message" \
            --arg content "$content_base64" \
            '{message: $msg, content: $content}')
    fi

    # Upload file
    local response
    response=$(github_api "PUT" "/contents/${remote_path}" "$json_payload")

    # Check for errors
    if echo "$response" | jq -e '.message' > /dev/null 2>&1; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.message')
        if [[ "$error_msg" != "null" ]] && [[ "$error_msg" != "" ]]; then
            log_error "Failed to upload $remote_path: $error_msg"
            return 1
        fi
    fi

    return 0
}

log_info "Setting up for GitHub API upload to ${REMOTE_REPO}..."

# Target base path in repository
TARGET_BASE="data/artifacts/${DATE_FOLDER}"
log_info "Target base directory: ${TARGET_BASE}"

# Track progress
FILES_COPIED=0
PROJECTS_PROCESSED=0
FAILED_FILES=0

log_info "Processing artifacts from: ${ARTIFACTS_DIR}"

# Debug: Show directory structure with files
log_info "Directory structure (first 30 items):"
find "${ARTIFACTS_DIR}" -maxdepth 3 2>/dev/null | head -30 || true
log_info ""

TOTAL_FILES=$(find "${ARTIFACTS_DIR}" -type f 2>/dev/null | wc -l | tr -d ' ')
log_info "Total items in artifacts directory: ${TOTAL_FILES}"

if [ "${TOTAL_FILES}" -eq 0 ]; then
    log_error "No files found in artifacts directory!"
    exit 1
fi

# Process each project's artifacts (reports-*)
while IFS= read -r -d '' artifact_dir; do
    SLUG=$(basename "$artifact_dir" | sed 's/^reports-//')

    log_info "Found artifact directory: ${artifact_dir}"
    log_info "Project slug: ${SLUG}"

    # Skip if no files in the report directory
    if [ -z "$(ls -A "$artifact_dir" 2>/dev/null)" ]; then
        log_warning "No files found in ${artifact_dir}"
        continue
    fi

    # Check if this specific project's directory already exists in the target repo
    PROJECT_TARGET_DIR="${TARGET_BASE}/reports-${SLUG}"
    EXISTING_PROJECT=$(get_file_sha "${PROJECT_TARGET_DIR}/README.md" 2>/dev/null || get_file_sha "${PROJECT_TARGET_DIR}/index.html" 2>/dev/null || echo "")

    if [ -n "$EXISTING_PROJECT" ]; then
        log_warning "Target directory already exists for project ${SLUG}: ${PROJECT_TARGET_DIR}"

        # Check if this is a manual workflow run
        if [ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ]; then
            log_warning "Manual workflow invocation detected - skipping ${SLUG} to avoid overwriting existing data"
            log_info "If you need to update the reports for ${SLUG}, please manually delete the existing folder in the target repository first"
            continue
        else
            log_warning "Scheduled run detected - will overwrite existing data for ${SLUG}"
        fi
    fi

    PROJECTS_PROCESSED=$((PROJECTS_PROCESSED + 1))
    log_info "Processing project: ${SLUG}"

    # Upload all files from this directory
    while IFS= read -r -d '' file; do
        # Get relative path from artifact_dir
        rel_path="${file#"${artifact_dir}"/}"
        remote_path="${TARGET_BASE}/reports-${SLUG}/${rel_path}"

        log_info "  Uploading: ${rel_path}"

        if upload_file "$file" "$remote_path"; then
            FILES_COPIED=$((FILES_COPIED + 1))
        else
            FAILED_FILES=$((FAILED_FILES + 1))
        fi

        # Add small delay to avoid rate limiting
        sleep 0.1
    done < <(find "$artifact_dir" -type f -print0 2>/dev/null)

    log_success "Processed ${SLUG}"

done < <(find "${ARTIFACTS_DIR}" -maxdepth 1 -type d -name "reports-*" -print0 2>/dev/null)

# Process raw data artifacts (raw-data-*)
while IFS= read -r -d '' artifact_dir; do
    SLUG=$(basename "$artifact_dir" | sed 's/^raw-data-//')

    log_info "Found raw data directory: ${artifact_dir}"

    # Skip if no files
    if [ -z "$(ls -A "$artifact_dir" 2>/dev/null)" ]; then
        log_warning "No raw data files found in ${artifact_dir}"
        continue
    fi

    # Check if this specific project's directory already exists in the target repo
    PROJECT_TARGET_DIR="${TARGET_BASE}/reports-${SLUG}"
    EXISTING_PROJECT=$(get_file_sha "${PROJECT_TARGET_DIR}/README.md" 2>/dev/null || get_file_sha "${PROJECT_TARGET_DIR}/index.html" 2>/dev/null || echo "")

    if [ -n "$EXISTING_PROJECT" ]; then
        log_warning "Target directory already exists for project ${SLUG}: ${PROJECT_TARGET_DIR}"

        # Check if this is a manual workflow run
        if [ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ]; then
            log_warning "Manual workflow invocation detected - skipping raw data for ${SLUG} to avoid overwriting existing data"
            log_info "If you need to update the raw data for ${SLUG}, please manually delete the existing folder in the target repository first"
            continue
        else
            log_warning "Scheduled run detected - will overwrite existing raw data for ${SLUG}"
        fi
    fi

    log_info "Processing raw data for: ${SLUG}"

    # Upload all files from this directory
    while IFS= read -r -d '' file; do
        # Get relative path from artifact_dir
        rel_path="${file#"${artifact_dir}"/}"
        remote_path="${TARGET_BASE}/reports-${SLUG}/${rel_path}"

        log_info "  Uploading: ${rel_path}"

        if upload_file "$file" "$remote_path"; then
            FILES_COPIED=$((FILES_COPIED + 1))
        else
            FAILED_FILES=$((FAILED_FILES + 1))
        fi

        # Add small delay to avoid rate limiting
        sleep 0.1
    done < <(find "$artifact_dir" -type f -print0 2>/dev/null)

    log_success "Processed raw data for ${SLUG}"

done < <(find "${ARTIFACTS_DIR}" -maxdepth 1 -type d -name "raw-data-*" -print0 2>/dev/null)

# Check if we actually copied anything
if [ $FILES_COPIED -eq 0 ] && [ $PROJECTS_PROCESSED -eq 0 ]; then
    log_error "No files were copied from artifacts and no projects were processed"
    exit 1
elif [ $FILES_COPIED -eq 0 ] && [ $PROJECTS_PROCESSED -gt 0 ]; then
    log_warning "No new files were copied (all projects may have been skipped due to existing data)"
    log_info "This is expected for manual runs when data already exists"
fi

log_success "Total files uploaded: ${FILES_COPIED}"
if [ $FAILED_FILES -gt 0 ]; then
    log_warning "Failed uploads: ${FAILED_FILES}"
fi
log_success "Total projects processed: ${PROJECTS_PROCESSED}"

# Create README.md with metadata
README_CONTENT="# Gerrit Reports - ${DATE_FOLDER}

Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Summary

- **Date**: ${DATE_FOLDER}
- **Projects Processed**: ${PROJECTS_PROCESSED}
- **Total Files**: ${FILES_COPIED}
- **Workflow Run**: ${GITHUB_RUN_ID:-N/A}
- **Trigger**: ${GITHUB_EVENT_NAME:-manual}

## Contents

This directory contains report artifacts for ${PROJECTS_PROCESSED} projects.

Each project has a subdirectory named \`reports-<slug>\` containing:
- Report HTML files and assets
- Raw JSON data files (\`report_raw.json\`, \`config_resolved.json\`, \`metadata.json\`)

## Projects

"

# List all project directories (from what we processed)
for artifact_dir in "${ARTIFACTS_DIR}"/reports-*; do
    if [ -d "$artifact_dir" ]; then
        SLUG=$(basename "$artifact_dir" | sed 's/^reports-//')
        FILE_COUNT=$(find "$artifact_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        README_CONTENT="${README_CONTENT}
- **${SLUG}**: ${FILE_COUNT} files"
    fi
done

# Create README in temp file
README_FILE=$(mktemp)
echo "$README_CONTENT" > "$README_FILE"

log_info "Creating README.md..."
if upload_file "$README_FILE" "${TARGET_BASE}/README.md"; then
    log_success "Created README.md"
else
    log_warning "Failed to create README.md"
fi

rm -f "$README_FILE"

log_success "✨ All artifacts successfully uploaded to gerrit-reports repository!"
log_info "View at: https://github.com/${REMOTE_REPO}/tree/main/${TARGET_BASE}"
