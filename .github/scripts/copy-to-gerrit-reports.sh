#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Script to copy report artifacts to the gerrit-reports repository
# This script is designed to run in GitHub Actions and copies:
# - Raw JSON data files
# - Report artifacts (HTML, etc.)
#
# Usage: copy-to-gerrit-reports.sh <date-folder> <artifacts-dir> <remote-repo> <token>

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
    log_error "  remote-repo: Remote repository URL (e.g., modeseven-lfit/gerrit-reports)"
    log_error "  token: GitHub PAT token for authentication"
    exit 1
fi

DATE_FOLDER="$1"
ARTIFACTS_DIR="$2"
REMOTE_REPO="$3"
GITHUB_TOKEN="$4"

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

# Set up git configuration
git config --global user.name "GitHub Actions Bot"
git config --global user.email "actions@github.com"

log_info "Setting up remote repository..."

# Create a temporary directory for the remote repo
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cd "$TEMP_DIR"

# Clone the remote repository (shallow clone for efficiency)
REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REMOTE_REPO}.git"
log_info "Cloning ${REMOTE_REPO}..."

if ! git clone --depth 1 "$REPO_URL" repo 2>/dev/null; then
    log_error "Failed to clone repository: ${REMOTE_REPO}"
    exit 1
fi

cd repo

log_success "Repository cloned successfully"

# Create the target directory structure
TARGET_BASE="data/artifacts/${DATE_FOLDER}"
log_info "Target base directory: ${TARGET_BASE}"

# Check if target directory already exists
if [ -d "$TARGET_BASE" ]; then
    log_warning "Target directory already exists: ${TARGET_BASE}"
    log_warning "This suggests reports have already been uploaded for this date"

    # Check if this is a manual workflow run
    if [ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ]; then
        log_warning "Manual workflow invocation detected - skipping upload to avoid overwriting existing data"
        log_info "If you need to update the reports, please manually delete the existing folder in the target repository first"
        exit 0
    else
        log_warning "Scheduled run detected - will overwrite existing data"
    fi
fi

# Create target directory
mkdir -p "$TARGET_BASE"
log_success "Created directory: ${TARGET_BASE}"

# Track whether we copied any files
FILES_COPIED=0
PROJECTS_PROCESSED=0

# Process each project's artifacts
log_info "Processing artifacts from: ${ARTIFACTS_DIR}"

# Debug: Show directory structure
log_info "Directory structure:"
find "${ARTIFACTS_DIR}" -maxdepth 2 -type d 2>/dev/null | head -20 || true

# Look for report artifacts (reports-*)
# GitHub Actions download-artifact creates nested dirs: downloaded-artifacts/reports-X/reports-X/files
for artifact_dir in "${ARTIFACTS_DIR}"/reports-*; do
    if [ ! -d "$artifact_dir" ]; then
        continue
    fi

    PROJECT_NAME=$(basename "$artifact_dir" | sed 's/^reports-//')

    # Check if there's a nested directory with the same name (GitHub Actions behavior)
    if [ -d "${artifact_dir}/reports-${PROJECT_NAME}" ]; then
        report_dir="${artifact_dir}/reports-${PROJECT_NAME}"
    else
        report_dir="$artifact_dir"
    fi

    # Skip if no files in the actual report directory
    if [ -z "$(ls -A "$report_dir" 2>/dev/null)" ]; then
        log_warning "No files found in ${report_dir}"
        continue
    fi

    PROJECTS_PROCESSED=$((PROJECTS_PROCESSED + 1))
    log_info "Processing project: ${PROJECT_NAME}"

    PROJECT_TARGET="${TARGET_BASE}/reports-${PROJECT_NAME}"
    mkdir -p "$PROJECT_TARGET"

    # Copy all files from the report directory
    cp -r "${report_dir}"/* "$PROJECT_TARGET/" 2>/dev/null || true

    # Count files copied
    FILE_COUNT=$(find "$PROJECT_TARGET" -type f | wc -l)
    FILES_COPIED=$((FILES_COPIED + FILE_COUNT))

    log_success "Copied ${FILE_COUNT} files for ${PROJECT_NAME}"
done

# Look for raw data artifacts (raw-data-*)
for artifact_dir in "${ARTIFACTS_DIR}"/raw-data-*; do
    if [ ! -d "$artifact_dir" ]; then
        continue
    fi

    PROJECT_NAME=$(basename "$artifact_dir" | sed 's/^raw-data-//')

    # Check if there's a nested directory with the same name (GitHub Actions behavior)
    if [ -d "${artifact_dir}/raw-data-${PROJECT_NAME}" ]; then
        raw_dir="${artifact_dir}/raw-data-${PROJECT_NAME}"
    else
        raw_dir="$artifact_dir"
    fi

    # Skip if no files
    if [ -z "$(ls -A "$raw_dir" 2>/dev/null)" ]; then
        log_warning "No raw data files found in ${raw_dir}"
        continue
    fi

    log_info "Processing raw data for: ${PROJECT_NAME}"

    PROJECT_TARGET="${TARGET_BASE}/reports-${PROJECT_NAME}"
    mkdir -p "$PROJECT_TARGET"

    # Copy raw data files (JSON files)
    cp -r "${raw_dir}"/* "$PROJECT_TARGET/" 2>/dev/null || true

    # Count JSON files
    JSON_COUNT=$(find "$raw_dir" -name "*.json" -type f | wc -l)
    FILES_COPIED=$((FILES_COPIED + JSON_COUNT))

    log_success "Copied ${JSON_COUNT} raw data files for ${PROJECT_NAME}"
done

# Check if we actually copied anything
if [ $FILES_COPIED -eq 0 ]; then
    log_error "No files were copied from artifacts"
    exit 1
fi

log_success "Total files copied: ${FILES_COPIED}"
log_success "Total projects processed: ${PROJECTS_PROCESSED}"

# Create a README in the date folder with metadata
README_FILE="${TARGET_BASE}/README.md"
cat > "$README_FILE" << EOF
# Gerrit Reports - ${DATE_FOLDER}

Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Summary

- **Date**: ${DATE_FOLDER}
- **Projects Processed**: ${PROJECTS_PROCESSED}
- **Total Files**: ${FILES_COPIED}
- **Workflow Run**: ${GITHUB_RUN_ID:-N/A}
- **Trigger**: ${GITHUB_EVENT_NAME:-manual}

## Contents

This directory contains report artifacts for ${PROJECTS_PROCESSED} projects.

Each project has a subdirectory named \`reports-<PROJECT_NAME>\` containing:
- Report HTML files and assets
- Raw JSON data files (\`report_raw.json\`, \`config_resolved.json\`, \`metadata.json\`)

## Projects

EOF

# List all project directories
for project_dir in "${TARGET_BASE}"/reports-*; do
    if [ -d "$project_dir" ]; then
        PROJECT_NAME=$(basename "$project_dir" | sed 's/^reports-//')
        FILE_COUNT=$(find "$project_dir" -type f | wc -l)
        echo "- **${PROJECT_NAME}**: ${FILE_COUNT} files" >> "$README_FILE"
    fi
done

log_success "Created README.md"

# Git add, commit, and push
log_info "Committing changes to repository..."

git add "${TARGET_BASE}"

# Create a descriptive commit message
COMMIT_MSG="Add report artifacts for ${DATE_FOLDER}

- Projects: ${PROJECTS_PROCESSED}
- Files: ${FILES_COPIED}
- Workflow: ${GITHUB_RUN_ID:-N/A}
- Event: ${GITHUB_EVENT_NAME:-manual}"

if git diff --cached --quiet; then
    log_warning "No changes to commit (files may already exist)"
    exit 0
fi

git commit -m "$COMMIT_MSG"

log_info "Pushing changes to remote repository..."
if git push origin main 2>/dev/null; then
    log_success "Successfully pushed artifacts to ${REMOTE_REPO}"
else
    log_error "Failed to push changes to remote repository"
    exit 1
fi

log_success "✨ All artifacts successfully copied to gerrit-reports repository!"
log_info "View at: https://github.com/${REMOTE_REPO}/tree/main/${TARGET_BASE}"
