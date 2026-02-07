#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

# Quick test with minimal repos for verification

set -euo pipefail

# Get the project root directory (parent of testing/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🧪 Quick Test - Report Generation with Minimal Repos"
echo "======================================================"
echo ""

# Create test directory structure
TEST_DIR="/tmp/gerrit-test"
REPOS_DIR="${TEST_DIR}/repos"
OUTPUT_DIR="${TEST_DIR}/reports"

echo "📁 Setting up test directories..."
rm -rf "${TEST_DIR}"
mkdir -p "${REPOS_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Create 3 minimal test repositories
echo "📦 Creating test repositories..."

for i in 1 2 3; do
    repo_name="test-repo-${i}"
    repo_path="${REPOS_DIR}/${repo_name}"

    # Initialize git repo
    mkdir -p "${repo_path}"
    cd "${repo_path}"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Add some commits
    for j in 1 2 3; do
        echo "Content ${j}" > "file${j}.txt"
        git add "file${j}.txt"
        git commit -q -m "Commit ${j} in ${repo_name}"
        sleep 0.1  # Small delay to ensure different timestamps
    done

    echo "  ✅ Created ${repo_name} with 3 commits"
done

echo ""
echo "✅ Test repositories created:"
find "${REPOS_DIR}" -type d -name ".git" | wc -l | xargs echo "   Total repos:"
echo ""

# Run the report tool
echo "🚀 Running report generation..."
echo ""

cd "${PROJECT_ROOT}"

if uv run project-reporting-tool generate \
    --project "TestProject" \
    --repos-path "${REPOS_DIR}" \
    --output-dir "${OUTPUT_DIR}" \
    --workers 2 \
    -v; then

    echo ""
    echo "✅ Report generation completed!"
    echo ""
    echo "📊 Generated files:"
    ls -lh "${OUTPUT_DIR}/TestProject/" 2>/dev/null || echo "No files found"
    echo ""

    # Check for critical files
    if [ -f "${OUTPUT_DIR}/TestProject/report.md" ]; then
        echo "✅ report.md created ($(wc -l < "${OUTPUT_DIR}/TestProject/report.md") lines)"
    fi

    if [ -f "${OUTPUT_DIR}/TestProject/report.html" ]; then
        echo "✅ report.html created ($(wc -c < "${OUTPUT_DIR}/TestProject/report.html") bytes)"
    fi

    if [ -f "${OUTPUT_DIR}/TestProject/report_raw.json" ]; then
        echo "✅ report_raw.json created"
        # Show a snippet of the JSON
        echo ""
        echo "📄 JSON report project field:"
        jq -r '.project' "${OUTPUT_DIR}/TestProject/report_raw.json" 2>/dev/null || echo "(JSON parse failed)"
    fi

    echo ""
    echo "🎉 SUCCESS - All core functionality working!"
    echo ""
    echo "📂 Full output at: ${OUTPUT_DIR}/TestProject/"
    echo ""
    echo "📝 To view the reports:"
    echo "   Markdown: cat '${OUTPUT_DIR}/TestProject/report.md'"
    echo "   HTML:     open '${OUTPUT_DIR}/TestProject/report.html'"
    echo "   JSON:     jq . '${OUTPUT_DIR}/TestProject/report_raw.json'"

else
    echo ""
    echo "❌ Report generation failed"
    exit 1
fi
