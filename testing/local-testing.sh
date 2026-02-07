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

# Script directory (assuming script is in project-reporting-tool/testing/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
CLONE_BASE_DIR="/tmp"
REPORT_BASE_DIR="/tmp/reports"
PROJECTS_JSON="${SCRIPT_DIR}/projects.json"

# SSH key configuration
SSH_KEY_PATH="${HOME}/.ssh/gerrit.linuxfoundation.org"

# Default verbosity level (empty for normal, -v, -vv, or -vvv)
VERBOSE_FLAG=""

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

# Copy reports to testing directory preserving structure
copy_reports_to_testing() {
    log_info "Copying reports to testing directory..."

    local testing_reports_dir="${SCRIPT_DIR}/reports"

    # Remove old testing/reports directory if it exists
    if [ -d "${testing_reports_dir}" ]; then
        log_info "  Removing old ${testing_reports_dir}"
        rm -rf "${testing_reports_dir}"
    fi

    # Copy entire /tmp/reports structure to testing/reports
    if [ -d "${REPORT_BASE_DIR}" ]; then
        log_info "  Copying ${REPORT_BASE_DIR} to ${testing_reports_dir}"
        cp -r "${REPORT_BASE_DIR}" "${testing_reports_dir}"
        log_success "  ✅ Reports copied successfully"
    else
        log_warning "  ⚠️  Report directory not found: ${REPORT_BASE_DIR}"
        return 1
    fi

    echo ""
}

# Download production reports from GitHub Pages into project directories
download_production_reports() {
    log_info "Downloading production reports from GitHub Pages..."

    local github_pages_base="https://modeseven-lfit.github.io/project-reporting-tool"
    local testing_reports_dir="${SCRIPT_DIR}/reports"

    local production_reports=(
        "onap:ONAP"
        "odl:Opendaylight"
    )

    for report_spec in "${production_reports[@]}"; do
        IFS=':' read -r project_slug project_dir <<< "$report_spec"
        local url="${github_pages_base}/${project_slug}/report.html"
        local output_dir="${testing_reports_dir}/${project_dir}"
        local output_path="${output_dir}/production-report.html"

        # Create directory if it doesn't exist
        if [ ! -d "${output_dir}" ]; then
            log_info "  Creating directory ${output_dir}"
            mkdir -p "${output_dir}"
        fi

        log_info "  Downloading ${project_slug} production report..."
        if command -v curl &> /dev/null; then
            if curl -fsSL -o "${output_path}" "${url}"; then
                log_success "  ✅ Downloaded to ${project_dir}/production-report.html"
            else
                log_warning "  ⚠️  Failed to download ${project_slug} report from ${url}"
            fi
        elif command -v wget &> /dev/null; then
            if wget -q -O "${output_path}" "${url}"; then
                log_success "  ✅ Downloaded to ${project_dir}/production-report.html"
            else
                log_warning "  ⚠️  Failed to download ${project_slug} report from ${url}"
            fi
        else
            log_error "Neither curl nor wget is available. Cannot download production reports."
            return 1
        fi
    done

    echo ""
}

# Load project metadata
load_project_metadata() {
    if [ ! -f "${PROJECTS_JSON}" ]; then
        log_error "Project metadata file not found: ${PROJECTS_JSON}"
        exit 1
    fi

    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON parsing:"
        log_error "  brew install jq  # macOS"
        log_error "  apt-get install jq  # Debian/Ubuntu"
        exit 1
    fi
}

# Get project info from metadata
get_project_info() {
    local project_name="$1"
    local field="$2"

    jq -r ".[] | select(.project == \"${project_name}\") | .${field} // empty" "${PROJECTS_JSON}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if uvx is available
    if ! command -v uvx &> /dev/null; then
        log_error "uvx is not installed. Please install uv first:"
        log_error "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi

    # Check if git is available
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. Please install git."
        exit 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq:"
        log_error "  brew install jq  # macOS"
        log_error "  apt-get install jq  # Debian/Ubuntu"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Check and configure SSH key
check_ssh_key() {
    log_info "Checking SSH key configuration..."

    # Check if SSH key is set in environment (CI mode)
    if [ -n "${LF_GERRIT_INFO_MASTER_SSH_KEY:-}" ]; then
        log_success "SSH key found in LF_GERRIT_INFO_MASTER_SSH_KEY environment variable"
        return 0
    fi

    # Check if SSH key file exists locally
    if [ -f "${SSH_KEY_PATH}" ]; then
        log_success "SSH key found at ${SSH_KEY_PATH}"

        # Set up SSH config for info-master access
        log_info "Configuring SSH for info-master access..."

        # Ensure SSH directory exists
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh

        # Check if SSH config already has the entry
        if ! grep -q "Host gerrit.linuxfoundation.org" ~/.ssh/config 2>/dev/null; then
            log_info "Adding SSH config entry for gerrit.linuxfoundation.org"
            cat >> ~/.ssh/config <<EOF

Host gerrit.linuxfoundation.org
    HostName gerrit.linuxfoundation.org
    User ${USER}
    Port 29418
    IdentityFile ${SSH_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
            chmod 600 ~/.ssh/config
        fi

        return 0
    fi

    # SSH key not found
    log_error "❌ SSH key not found: ${SSH_KEY_PATH}"
    log_error ""
    log_error "To fix this:"
    log_error "  1. Copy your Gerrit SSH key to: ${SSH_KEY_PATH}"
    log_error "  2. Or set LF_GERRIT_INFO_MASTER_SSH_KEY environment variable"
    log_error ""
    log_error "Example:"
    log_error "  cp ~/.ssh/id_rsa ${SSH_KEY_PATH}"
    log_error "  export LF_GERRIT_INFO_MASTER_SSH_KEY=\$(cat ~/.ssh/id_rsa)"
    exit 1
}

# Check API configuration
check_api_configuration() {
    log_info "Checking API configuration..."

    local has_github_token=false
    local github_token_env="GITHUB_TOKEN"

    # Check for GitHub token - support both GITHUB_TOKEN and CLASSIC_READ_ONLY_PAT_TOKEN
    if [ -n "${CLASSIC_READ_ONLY_PAT_TOKEN:-}" ]; then
        log_success "GitHub API: CLASSIC_READ_ONLY_PAT_TOKEN is set"
        has_github_token=true
        github_token_env="CLASSIC_READ_ONLY_PAT_TOKEN"
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        log_success "GitHub API: GITHUB_TOKEN is set"
        has_github_token=true
        github_token_env="GITHUB_TOKEN"
    else
        log_warning "GitHub API: Neither GITHUB_TOKEN nor CLASSIC_READ_ONLY_PAT_TOKEN is set"
    fi

    # Store the token env var name for later use
    export GITHUB_TOKEN_ENV="${github_token_env}"

    # Check for Gerrit config (optional - not used by current implementation)
    if [ -n "${GERRIT_HOST:-}" ]; then
        log_success "Gerrit API: GERRIT_HOST is set (${GERRIT_HOST})"
    else
        log_info "Gerrit API: Not configured (using projects.json configuration)"
    fi

    # Check for Jenkins config (optional - will use projects.json configuration)
    if [ -n "${JENKINS_HOST:-}" ]; then
        log_success "Jenkins API: JENKINS_HOST is set (${JENKINS_HOST})"
    else
        log_info "Jenkins API: Will use configuration from projects.json"
    fi

    echo ""

    if [ "$has_github_token" = false ]; then
        log_warning "=========================================="
        log_warning "⚠️  GITHUB TOKEN NOT SET"
        log_warning "=========================================="
        log_warning "Reports will use GitHub API with rate limits."
        log_warning ""
        log_warning "For full GitHub API access, set ONE of:"
        log_warning "  1. GITHUB_TOKEN environment variable"
        log_warning "  2. CLASSIC_READ_ONLY_PAT_TOKEN environment variable"
        log_warning ""
        log_warning "See testing/API_ACCESS.md for details"
        log_warning ""
        log_warning "Without a token, you may hit rate limits"
        log_warning "but reports will still include:"
        log_warning "  ✅ Local git data (commits, authors, etc.)"
        log_warning "  ✅ Jenkins CI/CD information (from projects.json)"
        log_warning "  ✅ INFO.yaml project data"
        log_warning "  ⚠️  GitHub workflows (limited by rate limits, NO STATUS COLORS)"
        log_warning "=========================================="
        echo ""
    else
        log_success "✅ Full API access configured using ${github_token_env}"
        log_success "   Reports will include GitHub workflow status colors"
    fi

    # Note about Jenkins and Gerrit
    log_info "📝 Note: Jenkins and Gerrit URLs are configured in testing/projects.json"
    log_info "   The report tool will automatically use those configurations."
}

# Clean up existing report directories only
cleanup_directories() {
    log_info "Cleaning up existing report directories..."

    if [ -d "${ONAP_REPORT_DIR}/ONAP" ]; then
        log_warning "Removing existing ${ONAP_REPORT_DIR}/ONAP"
        rm -rf "${ONAP_REPORT_DIR}/ONAP"
    fi

    if [ -d "${ODL_REPORT_DIR}/OpenDaylight" ]; then
        log_warning "Removing existing ${ODL_REPORT_DIR}/OpenDaylight"
        rm -rf "${ODL_REPORT_DIR}/OpenDaylight"
    fi

    log_success "Cleanup complete"
}



# Clone project repositories
clone_project() {
    local project_name="$1"
    local gerrit_host="$2"
    local clone_dir="${CLONE_BASE_DIR}/${gerrit_host}"

    if [ -d "${clone_dir}" ]; then
        log_warning "${project_name} repositories already exist at ${clone_dir}"
        log_warning "To re-clone with fresh data, delete the directory first:"
        log_warning "  rm -rf ${clone_dir}"
        log_info "Skipping clone, using existing repositories"
        return 0
    fi

    log_info "Cloning ${project_name} repositories from ${gerrit_host} to ${clone_dir}..."

    # Use gerrit-clone (the CLI tool) instead of gerrit-clone-action (the GitHub Action)
    if gerrit-clone clone \
        --host "${gerrit_host}" \
        --output-path "${clone_dir}" \
        --skip-archived \
        --threads 4 \
        --clone-timeout 600 \
        --retry-attempts 3 \
        --move-conflicting; then
        log_success "${project_name} repositories cloned successfully to ${clone_dir}"
        return 0
    else
        log_error "Failed to clone ${project_name} repositories"
        return 1
    fi
}

# Clone GitHub project repositories
clone_github_project() {
    local project_name="$1"
    local github_org="$2"
    local clone_dir="${CLONE_BASE_DIR}/${github_org}"

    if [ -d "${clone_dir}" ]; then
        log_warning "${project_name} repositories already exist at ${clone_dir}"
        log_warning "To re-clone with fresh data, delete the directory first:"
        log_warning "  rm -rf ${clone_dir}"
        log_info "Skipping clone, using existing repositories"
        return 0
    fi

    log_info "Cloning ${project_name} repositories from GitHub org ${github_org} to ${clone_dir}..."

    # Check if gerrit-clone CLI is available
    if ! command -v gerrit-clone &> /dev/null; then
        log_error "gerrit-clone CLI is not installed"
        log_error "Please install it from: https://github.com/lfit/releng-lftools"
        log_error "Or use: pip install gerrit-clone"
        return 1
    fi

    # Set up GitHub token for authentication
    local github_token="${CLASSIC_READ_ONLY_PAT_TOKEN:-${GITHUB_TOKEN:-}}"
    if [ -z "${github_token}" ]; then
        log_warning "No GitHub token found in CLASSIC_READ_ONLY_PAT_TOKEN or GITHUB_TOKEN"
        log_warning "Proceeding without authentication (may hit rate limits)"
    fi

    # Use gerrit-clone (the CLI tool) for multi-threaded GitHub cloning
    local clone_args=(
        --host "github.com/${github_org}"
        --source-type github
        --output-path "${CLONE_BASE_DIR}"
        --skip-archived
        --threads 8
        --clone-timeout 600
        --retry-attempts 5
        --retry-base-delay 3.0
        --retry-max-delay 60.0
        --https
    )

    # Add GitHub token if available
    if [ -n "${github_token}" ]; then
        clone_args+=(--github-token "${github_token}")
    fi

    # Add verbosity flag if set
    if [ -n "${VERBOSE_FLAG}" ]; then
        clone_args+=("${VERBOSE_FLAG}")
    fi

    log_info "Running gerrit-clone with multi-threaded GitHub cloning..."
    if gerrit-clone clone "${clone_args[@]}"; then
        log_success "${project_name} repositories cloned successfully"
        log_info "Clone directory: ${clone_dir}"
        return 0
    else
        log_error "Failed to clone ${project_name} repositories"
        return 1
    fi
}

# Generate project report
generate_project_report() {
    local project_name="$1"
    local source_identifier="$2"  # Either gerrit_host or github_org
    local jenkins_host="$3"
    local github_org="$4"
    local clone_dir="${CLONE_BASE_DIR}/${source_identifier}"

    log_info "Generating ${project_name} report..."

    # Extract Jenkins credentials from projects.json if available
    local jenkins_user
    local jenkins_token
    jenkins_user=$(get_project_info "${project_name}" "jenkins_user")
    jenkins_token=$(get_project_info "${project_name}" "jenkins_token")

    # Clear any existing Jenkins credentials to prevent cross-project contamination
    unset JENKINS_USER
    unset JENKINS_API_TOKEN

    # Set Jenkins credentials if found in projects.json
    if [ -n "${jenkins_user}" ] && [ -n "${jenkins_token}" ]; then
        export JENKINS_USER="${jenkins_user}"
        export JENKINS_API_TOKEN="${jenkins_token}"
        log_info "Using Jenkins credentials from projects.json for ${project_name}"
    fi

    if [ ! -d "${clone_dir}" ]; then
        log_error "${project_name} clone directory not found: ${clone_dir}"
        return 1
    fi

    # Count repositories in clone directory
    local repo_count
    repo_count=$(find "${clone_dir}" -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')
    log_info "Found ${repo_count} repositories in ${clone_dir}"

    cd "${REPO_ROOT}"

    # Build command with optional parameters
    local cmd="uv run project-reporting-tool generate \
        --project \"${project_name}\" \
        --repos-path \"${clone_dir}\" \
        --output-dir \"${REPORT_BASE_DIR}\" \
        --cache \
        --workers 4"

    # Add verbose flag if set
    if [ -n "${VERBOSE_FLAG}" ]; then
        cmd="${cmd} ${VERBOSE_FLAG}"
    fi

    # Add github-token-env flag if using CLASSIC_READ_ONLY_PAT_TOKEN
    if [ -n "${GITHUB_TOKEN_ENV:-}" ] && [ "${GITHUB_TOKEN_ENV}" != "GITHUB_TOKEN" ]; then
        cmd="${cmd} \
        --github-token-env \"${GITHUB_TOKEN_ENV}\""
    fi

    # Add Gerrit host if available (only for Gerrit projects)
    # For GitHub-native projects, source_identifier is the GitHub org
    if [ -n "${source_identifier}" ] && [[ "${source_identifier}" == *"gerrit"* || "${source_identifier}" == *"git."* ]]; then
        export GERRIT_HOST="${source_identifier}"
        export GERRIT_BASE_URL="https://${source_identifier}"
    fi

    # Add Jenkins host if available
    if [ -n "${jenkins_host}" ]; then
        export JENKINS_HOST="${jenkins_host}"
        export JENKINS_BASE_URL="https://${jenkins_host}"
    fi

    # Add GitHub org if available
    if [ -n "${github_org}" ]; then
        export GITHUB_ORG="${github_org}"
    fi

    # Execute the command
    if eval "${cmd}"; then
        log_success "${project_name} report generated successfully in ${REPORT_BASE_DIR}/${project_name}"
        return 0
    else
        log_error "Failed to generate ${project_name} report"
        return 1
    fi
}

# Display summary
show_summary() {
    echo ""
    log_info "=========================================="
    log_info "Testing Complete - Summary"
    log_info "=========================================="
    echo ""

    log_info "Clone Directories:"
    # Use a while loop with proper quoting to avoid jq parsing errors
    jq -c '.[]' "${PROJECTS_JSON}" 2>/dev/null | while IFS= read -r project_data; do
        local project
        project=$(echo "$project_data" | jq -r '.project // "Unknown"' 2>/dev/null)
        local gerrit
        gerrit=$(echo "$project_data" | jq -r '.gerrit // empty' 2>/dev/null)
        local github_org
        github_org=$(echo "$project_data" | jq -r '.github // empty' 2>/dev/null)

        if [ -n "${gerrit}" ]; then
            local clone_dir="${CLONE_BASE_DIR}/${gerrit}"
            if [ -d "${clone_dir}" ]; then
                echo "  - ${project} (Gerrit): ${clone_dir}"
            fi
        elif [ -n "${github_org}" ]; then
            local clone_dir="${CLONE_BASE_DIR}/${github_org}"
            if [ -d "${clone_dir}" ]; then
                echo "  - ${project} (GitHub): ${clone_dir}"
            fi
        fi
    done
    echo ""

    log_info "Report Directories:"
    echo "  - Source: ${REPORT_BASE_DIR}"
    echo "  - Testing copy: ${SCRIPT_DIR}/reports"
    echo ""

    log_info "Generated Reports in testing/reports/:"
    local testing_reports_dir="${SCRIPT_DIR}/reports"
    if [ -d "${testing_reports_dir}" ]; then
        for project_dir in "${testing_reports_dir}"/*; do
            if [ -d "${project_dir}" ]; then
                local project_name
                project_name=$(basename "${project_dir}")
                echo "  ${project_name}:"

                # Show main reports
                [ -f "${project_dir}/report.html" ] && echo "    📊 report.html ($(du -h "${project_dir}/report.html" 2>/dev/null | cut -f1))"
                [ -f "${project_dir}/production-report.html" ] && echo "    📊 production-report.html ($(du -h "${project_dir}/production-report.html" 2>/dev/null | cut -f1))"

                # Show other files
                [ -f "${project_dir}/report.md" ] && echo "    📄 report.md ($(du -h "${project_dir}/report.md" 2>/dev/null | cut -f1))"
                [ -f "${project_dir}/report_raw.json" ] && echo "    📄 report_raw.json ($(du -h "${project_dir}/report_raw.json" 2>/dev/null | cut -f1))"
                [ -f "${project_dir}/theme.css" ] && echo "    🎨 theme.css"

                echo ""
            fi
        done
    else
        log_warning "No reports found in ${testing_reports_dir}"
    fi

    log_success "You can now review the reports!"
    echo ""
    log_info "To compare reports, run the command:"
    echo "    open testing/reports/*/*report.html"
    echo ""
}

# Parse command-line arguments
parse_arguments() {
    SELECTED_PROJECT=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                SELECTED_PROJECT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE_FLAG="-v"
                shift
                ;;
            -vv|--debug)
                VERBOSE_FLAG="-vv"
                shift
                ;;
            -vvv|--trace)
                VERBOSE_FLAG="-vvv"
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --project NAME       Generate report for specific project only"
                echo "  -v, --verbose        Enable verbose output (INFO level)"
                echo "  -vv, --debug         Enable debug output (DEBUG level)"
                echo "  -vvv, --trace        Enable trace output (maximum verbosity)"
                echo "  -h, --help           Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                         # Process all projects"
                echo "  $0 --project Aether        # Process only Aether project"
                echo "  $0 --project ONAP -vv      # Process ONAP with debug output"
                echo "  $0 -v                      # Process all with verbose output"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Get list of projects to process
get_projects_to_process() {
    if [ -n "${SELECTED_PROJECT}" ]; then
        # Single project specified via --project flag
        echo "${SELECTED_PROJECT}"
    else
        # All projects from projects.json
        jq -r '.[].project' "${PROJECTS_JSON}"
    fi
}

# Main execution
main() {
    # Parse command-line arguments first
    parse_arguments "$@"

    log_info "=========================================="
    log_info "Local Testing Script for Reporting Tool"
    log_info "=========================================="
    echo ""

    # Show verbosity setting if enabled
    if [ -n "${VERBOSE_FLAG}" ]; then
        log_info "Verbosity: ${VERBOSE_FLAG}"
        echo ""
    fi

    # Step 1: Load project metadata
    load_project_metadata

    # Step 2: Check prerequisites
    check_prerequisites
    echo ""

    # Step 3: Check SSH key
    check_ssh_key
    echo ""

    # Step 4: Check API configuration
    check_api_configuration

    # Step 5: Create base directories
    mkdir -p "${CLONE_BASE_DIR}"
    mkdir -p "${REPORT_BASE_DIR}"

    # Get projects to process
    local projects
    readarray -t projects < <(get_projects_to_process)

    if [ ${#projects[@]} -eq 0 ]; then
        log_error "No projects to process"
        exit 1
    fi

    if [ -n "${SELECTED_PROJECT}" ]; then
        log_info "Processing single project: ${SELECTED_PROJECT}"
    else
        log_info "Processing all projects: ${projects[*]}"
    fi
    echo ""

    # Step 6: Clone repositories
    log_info "Step 1/3: Cloning Repositories"
    log_info "------------------------------------------"
    echo ""
    if [ -z "${SELECTED_PROJECT}" ]; then
        log_info "💡 To get fresh/complete data, delete existing clone directories first:"
        log_info "   rm -rf /tmp/gerrit.onap.org"
        log_info "   rm -rf /tmp/git.opendaylight.org"
        log_info "   rm -rf /tmp/opennetworkinglab"
        echo ""
    fi
    for project in "${projects[@]}"; do
        local gerrit_host
        gerrit_host=$(get_project_info "${project}" "gerrit")
        local github_org
        github_org=$(get_project_info "${project}" "github")

        # Determine project type and clone accordingly
        if [ -n "${gerrit_host}" ]; then
            # Gerrit-based project
            clone_project "${project}" "${gerrit_host}"
            echo ""
        elif [ -n "${github_org}" ]; then
            # GitHub-native project
            clone_github_project "${project}" "${github_org}"
            echo ""
        else
            log_warning "No source system found for ${project} (needs 'gerrit' or 'github' field)"
        fi
    done

    # Step 7: Generate reports
    log_info "Step 2/3: Generating Reports"
    log_info "------------------------------------------"
    for project in "${projects[@]}"; do
        local gerrit_host
        gerrit_host=$(get_project_info "${project}" "gerrit")
        local jenkins_host
        jenkins_host=$(get_project_info "${project}" "jenkins")
        local github_org
        github_org=$(get_project_info "${project}" "github")

        # Determine source identifier (gerrit_host or github_org)
        local source_identifier=""
        if [ -n "${gerrit_host}" ]; then
            source_identifier="${gerrit_host}"
        elif [ -n "${github_org}" ]; then
            source_identifier="${github_org}"
        fi

        if [ -n "${source_identifier}" ]; then
            # Clean up existing report directory for this project
            if [ -d "${REPORT_BASE_DIR}/${project}" ] && [ -n "${REPORT_BASE_DIR}" ] && [ -n "${project}" ]; then
                log_warning "Removing existing ${REPORT_BASE_DIR}/${project}"
                rm -rf "${REPORT_BASE_DIR:?}/${project}"
            fi

            generate_project_report "${project}" "${source_identifier}" "${jenkins_host}" "${github_org}"
            echo ""
        else
            log_warning "No source system found for ${project}, skipping report generation"
        fi
    done

    # Step 8: Copy reports to testing directory
    copy_reports_to_testing

    # Step 9: Download production reports
    download_production_reports

    # Step 10: Show summary
    show_summary
}

# Run main function
main "$@"
