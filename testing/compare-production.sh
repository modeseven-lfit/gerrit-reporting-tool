#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

# P6 Integration Testing - Production Report Comparison Script
# Compares modern system output with production ONAP report

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROD_REPORT="${SCRIPT_DIR}/onap-production-report.html"
TEST_REPORT_DIR="/tmp/reports/ONAP"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_CHECKS=0

# Functions
log_section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$*${NC}"
    echo -e "${CYAN}========================================${NC}"
}

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $*"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

log_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $*"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $*"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_warn() {
    echo -e "${YELLOW}[! WARN]${NC} $*"
    WARN_COUNT=$((WARN_COUNT + 1))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Check if production report exists
check_production_report() {
    log_section "Checking Production Report"

    if [ ! -f "${PROD_REPORT}" ]; then
        log_fail "Production report not found: ${PROD_REPORT}"
        exit 1
    fi

    log_pass "Production report found"
    log_info "Report: ${PROD_REPORT}"
    log_info "Lines: $(wc -l < "${PROD_REPORT}")"
}

# Check for test report (if exists)
check_test_report() {
    log_section "Checking Test Report"

    if [ -d "${TEST_REPORT_DIR}" ]; then
        log_info "Test report directory exists: ${TEST_REPORT_DIR}"

        if [ -f "${TEST_REPORT_DIR}/report.md" ]; then
            log_pass "Markdown report exists"
            log_info "Lines: $(wc -l < "${TEST_REPORT_DIR}/report.md")"
        else
            log_warn "Markdown report not found (run ./local-testing.sh to generate)"
        fi

        if [ -f "${TEST_REPORT_DIR}/report.html" ]; then
            log_pass "HTML report exists"
            log_info "Size: $(du -h "${TEST_REPORT_DIR}/report.html" | cut -f1)"
        else
            log_warn "HTML report not found"
        fi

        if [ -f "${TEST_REPORT_DIR}/report_raw.json" ]; then
            log_pass "JSON report exists"
            log_info "Size: $(du -h "${TEST_REPORT_DIR}/report_raw.json" | cut -f1)"
        else
            log_warn "JSON report not found"
        fi
    else
        log_warn "Test report directory not found: ${TEST_REPORT_DIR}"
        log_info "Run './local-testing.sh' to generate ONAP report"
    fi
}

# Verify section structure
verify_section_structure() {
    log_section "Verifying Section Structure"

    # Check production report for expected sections
    log_check "Production report has all expected sections"

    local sections=(
        "Project Analysis Report"
        "📈 Global Summary"
        "🏢 Top Organizations"
    )

    local all_found=true
    for section in "${sections[@]}"; do
        if grep -q "$section" "${PROD_REPORT}"; then
            log_pass "Section found: $section"
        else
            log_fail "Section missing: $section"
            all_found=false
        fi
    done

    if [ "$all_found" = true ]; then
        log_pass "All critical sections present in production report"
    fi
}

# Verify header format
verify_header_format() {
    log_section "Verifying Header Format"

    log_check "Title format"
    if grep -q "# 📊 Gerrit Project Analysis Report: ONAP" "${PROD_REPORT}" || \
       grep -q "# 📊 GitHub Project Analysis Report: ONAP" "${PROD_REPORT}"; then
        log_pass "Title has correct format with emoji"
    else
        log_fail "Title format incorrect or missing emoji"
    fi

    log_check "Generation timestamp"
    if grep -q "Generated:" "${PROD_REPORT}"; then
        log_pass "Generation timestamp present"
        local timestamp
        timestamp=$(grep "Generated:" "${PROD_REPORT}" | head -1)
        log_info "Timestamp: ${timestamp}"
    else
        log_fail "Generation timestamp missing"
    fi

    log_check "Schema version"
    if grep -q "Schema Version:" "${PROD_REPORT}"; then
        log_pass "Schema version present"
        local version
        version=$(grep "Schema Version:" "${PROD_REPORT}" | head -1)
        log_info "Version: ${version}"
    else
        log_warn "Schema version missing"
    fi
}

# Verify global summary
verify_global_summary() {
    log_section "Verifying Global Summary Section"

    log_check "Status legend"
    local legend_items=("✅ Current" "☑️ Active" "🛑 Inactive")

    for item in "${legend_items[@]}"; do
        if grep -q "$item" "${PROD_REPORT}"; then
            log_pass "Legend item present: $item"
        else
            log_fail "Legend item missing: $item"
        fi
    done

    log_check "Repository metrics"
    local metrics=(
        "Total Gerrit Projects"
        "Current Gerrit Projects"
        "Active Gerrit Projects"
        "Inactive Gerrit Projects"
        "Total Commits"
        "Total Lines of Code"
    )

    for metric in "${metrics[@]}"; do
        if grep -q "$metric" "${PROD_REPORT}"; then
            log_pass "Metric present: $metric"
        else
            log_warn "Metric missing: $metric"
        fi
    done

    log_check "Percentage calculations"
    if grep -q "%" "${PROD_REPORT}"; then
        log_pass "Percentages present in report"
        local pct_count
        pct_count=$(grep -o "[0-9]\+\.[0-9]\+%" "${PROD_REPORT}" | wc -l)
        log_info "Found ${pct_count} percentage values"
    else
        log_fail "No percentages found"
    fi
}

# Verify organizations section
verify_organizations_section() {
    log_section "Verifying Top Organizations Section"

    log_check "Section header"
    if grep -q "🏢 Top Organizations" "${PROD_REPORT}"; then
        log_pass "Section header has emoji"
    else
        log_fail "Section header missing emoji"
    fi

    log_check "Timeframe header"
    if grep -q "past 365 days" "${PROD_REPORT}"; then
        log_pass "Timeframe header present"
    else
        log_warn "Timeframe header missing"
    fi

    log_check "Organization count"
    if grep -q "Organizations Found:" "${PROD_REPORT}"; then
        log_pass "Organization count header present"
        local count
        count=$(grep "Organizations Found:" "${PROD_REPORT}" | grep -o "[0-9]\+")
        log_info "Organizations: ${count}"
    else
        log_warn "Organization count header missing"
    fi

    log_check "Table columns"
    local columns=(
        "Organization"
        "Contributors"
        "Commits"
        "LOC"
        "Δ LOC"
        "Avg LOC/Commit"
        "Unique Repositories"
    )

    for col in "${columns[@]}"; do
        if grep -q "$col" "${PROD_REPORT}"; then
            log_pass "Column present: $col"
        else
            log_fail "Column missing: $col"
        fi
    done

    log_check "LOC formatting (+ prefix)"
    if grep -q "+[0-9]" "${PROD_REPORT}"; then
        log_pass "LOC values have '+' prefix"
        local examples
        examples=$(grep -o "+[0-9]\+[KM]\?" "${PROD_REPORT}" | head -3 | tr '\n' ' ')
        log_info "Examples: ${examples}"
    else
        log_fail "LOC values missing '+' prefix"
    fi

    log_check "Number formatting (K/M notation)"
    if grep -qE "[0-9]+\.[0-9]+[KM]" "${PROD_REPORT}"; then
        log_pass "Numbers use K/M notation"
        local examples
        examples=$(grep -oE "[0-9]+\.[0-9]+[KM]" "${PROD_REPORT}" | head -3 | tr '\n' ' ')
        log_info "Examples: ${examples}"
    else
        log_warn "K/M notation not found (may be small numbers)"
    fi
}

# Verify footer
verify_footer() {
    log_section "Verifying Footer"

    log_check "Footer branding"
    if grep -q "Generated with ❤️ by Release Engineering" "${PROD_REPORT}"; then
        log_pass "Footer has correct branding"
    elif grep -q "Generated with" "${PROD_REPORT}"; then
        log_warn "Footer present but branding may differ"
    else
        log_fail "Footer branding missing"
    fi
}

# Extract and display key metrics
extract_key_metrics() {
    log_section "Key Metrics from Production Report"

    # Total projects
    local total_projects
    total_projects=$(grep "Total Gerrit Projects" "${PROD_REPORT}" | grep -oE "[0-9]+" | head -1)
    log_info "Total Projects: ${total_projects:-N/A}"

    # Current projects
    local current
    current=$(grep "Current Gerrit Projects" "${PROD_REPORT}" | grep -oE "[0-9]+" | head -1)
    local current_pct
    current_pct=$(grep "Current Gerrit Projects" "${PROD_REPORT}" | grep -oE "[0-9]+\.[0-9]+%" | head -1)
    log_info "Current Projects: ${current:-N/A} (${current_pct:-N/A})"

    # Total commits
    local commits
    commits=$(grep "Total Commits" "${PROD_REPORT}" | grep -oE "[0-9]+\.[0-9]+[KM]" | head -1)
    log_info "Total Commits: ${commits:-N/A}"

    # Total LOC
    local loc
    loc=$(grep "Total Lines of Code" "${PROD_REPORT}" | grep -oE "[0-9]+\.[0-9]+[KM]" | head -1)
    log_info "Total LOC: ${loc:-N/A}"

    # Top organizations
    log_info "Top 3 Organizations:"
    grep -A 3 "| 1 |" "${PROD_REPORT}" | grep "| [123] |" | while read -r line; do
        log_info "  ${line}"
    done
}

# Generate summary
generate_summary() {
    log_section "Test Summary"

    echo ""
    echo -e "${CYAN}Total Checks:${NC} ${TOTAL_CHECKS}"
    echo -e "${GREEN}Passed:${NC}       ${PASS_COUNT}"
    echo -e "${RED}Failed:${NC}       ${FAIL_COUNT}"
    echo -e "${YELLOW}Warnings:${NC}     ${WARN_COUNT}"
    echo ""

    local pass_rate=0
    if [ $TOTAL_CHECKS -gt 0 ]; then
        pass_rate=$((100 * PASS_COUNT / TOTAL_CHECKS))
    fi

    echo -e "${CYAN}Pass Rate:${NC}    ${pass_rate}%"
    echo ""

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}✓ All critical checks passed!${NC}"
        echo -e "${GREEN}Production report format matches expected template output.${NC}"
        return 0
    else
        echo -e "${RED}✗ Some checks failed.${NC}"
        echo -e "${YELLOW}Review failures above and verify template implementation.${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║   P6 Integration Testing - Production Comparison      ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_production_report
    check_test_report
    verify_section_structure
    verify_header_format
    verify_global_summary
    verify_organizations_section
    verify_footer
    extract_key_metrics

    echo ""
    generate_summary
}

# Run main
main "$@"
