#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
CLONE_BASE_DIR="/tmp"
PROJECTS_JSON="${SCRIPT_DIR}/projects.json"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Get project info from metadata
get_project_info() {
    local project_name="$1"
    local field="$2"

    jq -r ".[] | select(.project == \"${project_name}\") | .${field} // empty" "${PROJECTS_JSON}"
}

# Clean existing clone directory
clean_clone_dir() {
    local project_name="$1"
    local gerrit_host="$2"
    local clone_dir="${CLONE_BASE_DIR}/${gerrit_host}"

    if [ -d "${clone_dir}" ]; then
        log_warning "Removing existing clone directory: ${clone_dir}"

        # Count repos before deletion
        local repo_count
        repo_count=$(find "${clone_dir}" -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')

        # Calculate size
        local size
        size=$(du -sh "${clone_dir}" 2>/dev/null | cut -f1)

        log_info "  - Contains ${repo_count} repositories"
        log_info "  - Size: ${size}"

        # Confirm deletion
        if [ "${AUTO_CONFIRM:-false}" != "true" ]; then
            echo ""
            read -p "$(echo -e "${YELLOW}Delete this directory? [y/N]:${NC} ")" -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping deletion of ${clone_dir}"
                return 1
            fi
        fi

        rm -rf "${clone_dir}"
        log_success "Deleted ${clone_dir}"
        return 0
    else
        log_info "${project_name} clone directory does not exist at ${clone_dir}"
        return 1
    fi
}

# Clone project repositories
clone_project() {
    local project_name="$1"
    local gerrit_host="$2"
    local clone_dir="${CLONE_BASE_DIR}/${gerrit_host}"

    log_info "Cloning ${project_name} repositories from ${gerrit_host}..."
    log_info "Target directory: ${clone_dir}"
    echo ""

    # Check if gerrit-clone is available
    if ! command -v gerrit-clone &> /dev/null; then
        log_error "gerrit-clone is not installed"
        log_error ""
        log_error "Install with:"
        log_error "  uvx gerrit-clone@latest --help"
        log_error ""
        log_error "Or install permanently:"
        log_error "  uv tool install gerrit-clone"
        exit 1
    fi

    # Show gerrit-clone version
    local version
    version=$(gerrit-clone --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_info "Using gerrit-clone version: ${version}"
    echo ""

    # Run the clone operation
    if gerrit-clone clone \
        --host "${gerrit_host}" \
        --output-path "${clone_dir}" \
        --skip-archived \
        --threads 4 \
        --clone-timeout 600 \
        --retry-attempts 3 \
        --move-conflicting; then

        # Count cloned repos
        local repo_count
        repo_count=$(find "${clone_dir}" -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')

        # Calculate size
        local size
        size=$(du -sh "${clone_dir}" 2>/dev/null | cut -f1)

        log_success "${project_name} repositories cloned successfully"
        log_success "  - Cloned ${repo_count} repositories"
        log_success "  - Size: ${size}"
        log_success "  - Location: ${clone_dir}"
        return 0
    else
        log_error "Failed to clone ${project_name} repositories"
        return 1
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Clean and Re-clone Script"
    log_info "=========================================="
    echo ""

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq:"
        log_error "  brew install jq  # macOS"
        log_error "  apt-get install jq  # Debian/Ubuntu"
        exit 1
    fi

    # Check if projects.json exists
    if [ ! -f "${PROJECTS_JSON}" ]; then
        log_error "Project metadata file not found: ${PROJECTS_JSON}"
        exit 1
    fi

    # Parse command line arguments
    if [ $# -eq 0 ]; then
        log_info "Usage: $0 [PROJECT_NAME...] [--all] [--yes]"
        log_info ""
        log_info "Examples:"
        log_info "  $0 ONAP                    # Clean and re-clone ONAP only"
        log_info "  $0 ONAP Opendaylight       # Clean and re-clone both"
        log_info "  $0 --all                   # Clean and re-clone all projects"
        log_info "  $0 ONAP --yes              # Skip confirmation prompts"
        log_info ""
        log_info "Available projects:"
        jq -r '.[].project' "${PROJECTS_JSON}" | while read -r project; do
            local gerrit_host
            gerrit_host=$(get_project_info "${project}" "gerrit")
            if [ -n "${gerrit_host}" ]; then
                echo "  - ${project} (${gerrit_host})"
            fi
        done
        exit 1
    fi

    # Parse arguments
    local projects=()

    for arg in "$@"; do
        if [ "$arg" = "--all" ]; then
            # Get all projects with gerrit hosts
            while IFS= read -r project; do
                projects+=("$project")
            done < <(jq -r '.[] | select(.gerrit != null) | .project' "${PROJECTS_JSON}")
        elif [ "$arg" = "--yes" ] || [ "$arg" = "-y" ]; then
            export AUTO_CONFIRM=true
        else
            projects+=("$arg")
        fi
    done

    if [ ${#projects[@]} -eq 0 ]; then
        log_error "No projects specified"
        exit 1
    fi

    log_info "Projects to process: ${projects[*]}"
    echo ""

    # Process each project
    local total_cleaned=0
    local total_cloned=0
    local total_failed=0

    for project in "${projects[@]}"; do
        log_info "=========================================="
        log_info "Processing: ${project}"
        log_info "=========================================="
        echo ""

        # Get gerrit host
        local gerrit_host
        gerrit_host=$(get_project_info "${project}" "gerrit")

        if [ -z "${gerrit_host}" ]; then
            log_error "No Gerrit host found for project: ${project}"
            ((total_failed++))
            echo ""
            continue
        fi

        log_info "Gerrit host: ${gerrit_host}"
        echo ""

        # Step 1: Clean existing directory
        if clean_clone_dir "${project}" "${gerrit_host}"; then
            ((total_cleaned++))
        fi
        echo ""

        # Step 2: Clone repositories
        if clone_project "${project}" "${gerrit_host}"; then
            ((total_cloned++))
        else
            ((total_failed++))
        fi
        echo ""
    done

    # Summary
    log_info "=========================================="
    log_info "Summary"
    log_info "=========================================="
    echo ""
    log_info "Projects processed: ${#projects[@]}"
    log_success "Directories cleaned: ${total_cleaned}"
    log_success "Projects cloned: ${total_cloned}"
    if [ ${total_failed} -gt 0 ]; then
        log_error "Failed: ${total_failed}"
    fi
    echo ""

    if [ ${total_cloned} -gt 0 ]; then
        log_success "✅ Re-cloning completed successfully!"
        log_info ""
        log_info "Next steps:"
        log_info "  1. Run the testing script:"
        log_info "     cd testing && ./local-testing.sh"
        log_info ""
        log_info "  2. Or generate reports directly:"
        log_info "     uv run project-reporting-tool generate --project ONAP --repos-path /tmp/gerrit.onap.org"
    else
        log_warning "No projects were cloned successfully"
    fi
}

# Run main function
main "$@"
