#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Validate projects.json schema
# This script performs the same validation as the GitHub Actions workflow

set -euo pipefail

# Default to testing/projects.json if no argument provided
PROJECTS_FILE="${1:-testing/projects.json}"

# Check if file exists
if [[ ! -f "$PROJECTS_FILE" ]]; then
  echo "::error::File not found: $PROJECTS_FILE"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "::error::jq is required but not installed. Please install jq to continue."
  exit 1
fi

echo "Validating $PROJECTS_FILE..."

# Read the file content
projects_json=$(cat "$PROJECTS_FILE")

# Validate JSON syntax
if ! echo "$projects_json" | jq . > /dev/null 2>&1; then
  echo "::error::$PROJECTS_FILE contains invalid JSON"
  exit 1
fi

# Validate structure
if ! echo "$projects_json" | jq -e 'type == "array"' > /dev/null; then
  echo "::error::$PROJECTS_FILE must be an array"
  exit 1
fi

# Validate required fields
# Each project must have 'project' and 'slug',
# plus either 'gerrit' or 'github'
if ! echo "$projects_json" | \
  jq -e 'all(.project and .slug and (.gerrit or .github))' \
  > /dev/null; then
  echo "::error::Each project must have 'project' and 'slug' fields, plus at least one of 'gerrit' or 'github' fields"
  exit 1
fi

project_count=$(echo "$projects_json" | jq '. | length')
echo "✅ Validation passed! Found $project_count project(s)"

# Display project summary
echo ""
echo "Projects:"
echo "$projects_json" | jq -r '
  .[] |
  if .gerrit != null and .gerrit != "" then
    "  - \(.project) [\(.slug)]: Gerrit: \(.gerrit)" +
    (if .github != null and .github != "" then ", GitHub: \(.github)" else "" end)
  else
    "  - \(.project) [\(.slug)]: GitHub: \(.github)"
  end
'

exit 0
