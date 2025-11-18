#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

set -euo pipefail

# Generate index.html for GitHub Pages
# Usage: generate-index.sh <report_dir> [environment]
#   report_dir: Directory containing reports (e.g., "production" or "pr-preview/123")
#   environment: "production" or "pr-preview" (default: production)

REPORT_DIR="${1:-production}"
ENVIRONMENT="${2:-production}"

echo "📄 Generating index page for: $REPORT_DIR"

# Determine the base path for links
if [ "$ENVIRONMENT" = "pr-preview" ]; then
  BASE_PATH="/$REPORT_DIR"
  PAGE_TITLE="Report Preview"
  PAGE_SUBTITLE="Preview reports for changes under review"
else
  BASE_PATH="/production"
  PAGE_TITLE="Production Reports"
  PAGE_SUBTITLE="Official Linux Foundation project reports"
fi

# Find all report.html files
REPORTS=()
if [ -d "$REPORT_DIR" ]; then
  while IFS= read -r -d '' report_file; do
    project_dir=$(dirname "$report_file")
    project_slug=$(basename "$project_dir")

    # Get project name from metadata if available
    project_name="$project_slug"
    metadata_file="$project_dir/metadata.json"
    if [ -f "$metadata_file" ]; then
      project_name=$(jq -r --arg slug "$project_slug" '.project // $slug' "$metadata_file")
      generated_at=$(jq -r '.generated_at // "N/A"' "$metadata_file")
    else
      generated_at="N/A"
    fi

    REPORTS+=("$project_slug|$project_name|$generated_at")
  done < <(find "$REPORT_DIR" -name "report.html" -print0)
fi

report_count=${#REPORTS[@]}
echo "Found $report_count report(s)"

# Generate HTML
cat > "$REPORT_DIR/index.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TITLE_PLACEHOLDER - Linux Foundation Reports</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
                   'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 2rem 1rem;
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
    }

    header {
      background: white;
      border-radius: 12px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }

    h1 {
      font-size: 2.5rem;
      margin-bottom: 0.5rem;
      color: #2d3748;
    }

    .subtitle {
      font-size: 1.1rem;
      color: #718096;
      margin-bottom: 1rem;
    }

    .meta {
      display: flex;
      gap: 2rem;
      flex-wrap: wrap;
      font-size: 0.9rem;
      color: #718096;
      padding-top: 1rem;
      border-top: 1px solid #e2e8f0;
    }

    .meta-item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }

    .meta-icon {
      font-size: 1.2rem;
    }

    main {
      background: white;
      border-radius: 12px;
      padding: 2rem;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }

    .reports-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1.5rem;
      padding-bottom: 1rem;
      border-bottom: 2px solid #e2e8f0;
    }

    .reports-title {
      font-size: 1.5rem;
      color: #2d3748;
    }

    .report-count {
      background: #667eea;
      color: white;
      padding: 0.5rem 1rem;
      border-radius: 20px;
      font-weight: 600;
    }

    .reports-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1.5rem;
    }

    .report-card {
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 1.5rem;
      transition: all 0.3s ease;
      background: #fafafa;
    }

    .report-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 8px 16px rgba(102, 126, 234, 0.2);
      border-color: #667eea;
    }

    .report-name {
      font-size: 1.25rem;
      font-weight: 600;
      color: #2d3748;
      margin-bottom: 0.5rem;
    }

    .report-info {
      font-size: 0.85rem;
      color: #718096;
      margin-bottom: 1rem;
    }

    .report-links {
      display: flex;
      gap: 0.75rem;
      flex-wrap: wrap;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.5rem 1rem;
      border-radius: 6px;
      text-decoration: none;
      font-weight: 500;
      font-size: 0.9rem;
      transition: all 0.2s ease;
    }

    .btn-primary {
      background: #667eea;
      color: white;
    }

    .btn-primary:hover {
      background: #5568d3;
      transform: translateY(-1px);
    }

    .btn-secondary {
      background: #e2e8f0;
      color: #4a5568;
    }

    .btn-secondary:hover {
      background: #cbd5e0;
    }

    .empty-state {
      text-align: center;
      padding: 4rem 2rem;
      color: #718096;
    }

    .empty-state-icon {
      font-size: 4rem;
      margin-bottom: 1rem;
    }

    footer {
      text-align: center;
      padding: 2rem;
      color: white;
      margin-top: 2rem;
    }

    footer a {
      color: white;
      text-decoration: underline;
    }

    @media (max-width: 768px) {
      h1 {
        font-size: 2rem;
      }

      .reports-grid {
        grid-template-columns: 1fr;
      }

      .meta {
        flex-direction: column;
        gap: 0.5rem;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📊 TITLE_PLACEHOLDER</h1>
      <p class="subtitle">SUBTITLE_PLACEHOLDER</p>
      <div class="meta">
        <div class="meta-item">
          <span class="meta-icon">🕐</span>
          <span>Generated: TIMESTAMP_PLACEHOLDER</span>
        </div>
        <div class="meta-item">
          <span class="meta-icon">🏢</span>
          <span>Linux Foundation</span>
        </div>
        <div class="meta-item">
          <span class="meta-icon">🔄</span>
          <span>ENVIRONMENT_BADGE_PLACEHOLDER</span>
        </div>
      </div>
    </header>

    <main>
      <div class="reports-header">
        <h2 class="reports-title">Available Reports</h2>
        <span class="report-count">REPORT_COUNT_PLACEHOLDER reports</span>
      </div>

      REPORTS_CONTENT_PLACEHOLDER
    </main>

    <footer>
      <p>
        Generated by
        <a href="https://github.com/lf-it/reporting-tool" target="_blank">
          Linux Foundation Reporting Tool
        </a>
      </p>
      <p style="margin-top: 0.5rem; font-size: 0.9rem;">
        &copy; 2025 The Linux Foundation | Apache-2.0 License
      </p>
    </footer>
  </div>
</body>
</html>
HTMLEOF

# Generate reports HTML content
if [ "$report_count" -eq 0 ]; then
  REPORTS_HTML='
      <div class="empty-state">
        <div class="empty-state-icon">📭</div>
        <h3>No Reports Available</h3>
        <p>Reports will appear here once they are generated.</p>
      </div>'
else
  REPORTS_HTML='<div class="reports-grid">'

  for report_entry in "${REPORTS[@]}"; do
    IFS='|' read -r slug name timestamp <<< "$report_entry"

    # Format timestamp for display
    if [ "$timestamp" = "N/A" ]; then
      display_time="N/A"
    else
      display_time=$(date -d "$timestamp" "+%Y-%m-%d %H:%M UTC" 2>/dev/null || echo "$timestamp")
    fi

    REPORTS_HTML+="
        <div class=\"report-card\">
          <div class=\"report-name\">$name</div>
          <div class=\"report-info\">
            <div>🔖 Slug: <code>$slug</code></div>
            <div>📅 Generated: $display_time</div>
          </div>
          <div class=\"report-links\">
            <a href=\"$BASE_PATH/$slug/report.html\" class=\"btn btn-primary\">
              📊 View Report
            </a>
            <a href=\"$BASE_PATH/$slug/report_raw.json\" class=\"btn btn-secondary\">
              📄 JSON
            </a>
          </div>
        </div>"
  done

  REPORTS_HTML+='
      </div>'
fi

# Determine environment badge
if [ "$ENVIRONMENT" = "pr-preview" ]; then
  ENV_BADGE="Preview Environment"
else
  ENV_BADGE="Production Environment"
fi

# Get current timestamp
CURRENT_TIME=$(date -u +"%Y-%m-%d %H:%M UTC")

# Replace placeholders - use a temp file for complex HTML replacement
sed "s|TITLE_PLACEHOLDER|$PAGE_TITLE|g" "$REPORT_DIR/index.html" | \
sed "s|SUBTITLE_PLACEHOLDER|$PAGE_SUBTITLE|g" | \
sed "s|TIMESTAMP_PLACEHOLDER|$CURRENT_TIME|g" | \
sed "s|ENVIRONMENT_BADGE_PLACEHOLDER|$ENV_BADGE|g" | \
sed "s|REPORT_COUNT_PLACEHOLDER|$report_count|g" > "$REPORT_DIR/index.html.tmp"

# Replace the REPORTS_CONTENT_PLACEHOLDER using awk for better handling of multiline content
awk -v reports="$REPORTS_HTML" '{
  if ($0 ~ /REPORTS_CONTENT_PLACEHOLDER/) {
    print reports
  } else {
    print $0
  }
}' "$REPORT_DIR/index.html.tmp" > "$REPORT_DIR/index.html"

rm "$REPORT_DIR/index.html.tmp"

echo "✅ Index page generated: $REPORT_DIR/index.html"

# If this is the main production directory, also create a root index
if [ "$REPORT_DIR" = "production" ] && [ ! -f "index.html" ]; then
  echo "📄 Creating root index page"

  cat > index.html <<'ROOTHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Linux Foundation Reports</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
                   'Helvetica Neue', Arial, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 2rem;
    }

    .container {
      background: white;
      border-radius: 16px;
      padding: 3rem;
      max-width: 600px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
      text-align: center;
    }

    h1 {
      font-size: 2.5rem;
      margin-bottom: 1rem;
      color: #2d3748;
    }

    .subtitle {
      font-size: 1.2rem;
      color: #718096;
      margin-bottom: 2rem;
    }

    .links {
      display: flex;
      flex-direction: column;
      gap: 1rem;
      margin-top: 2rem;
    }

    .link-card {
      display: flex;
      align-items: center;
      gap: 1rem;
      padding: 1.5rem;
      border: 2px solid #e2e8f0;
      border-radius: 12px;
      text-decoration: none;
      color: #2d3748;
      transition: all 0.3s ease;
    }

    .link-card:hover {
      border-color: #667eea;
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
    }

    .link-icon {
      font-size: 2rem;
    }

    .link-content {
      text-align: left;
      flex: 1;
    }

    .link-title {
      font-size: 1.25rem;
      font-weight: 600;
      margin-bottom: 0.25rem;
    }

    .link-desc {
      font-size: 0.9rem;
      color: #718096;
    }

    footer {
      margin-top: 2rem;
      padding-top: 2rem;
      border-top: 1px solid #e2e8f0;
      font-size: 0.9rem;
      color: #718096;
    }

    footer a {
      color: #667eea;
      text-decoration: none;
    }

    footer a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>📊 Linux Foundation</h1>
    <p class="subtitle">Project Reporting System</p>

    <div class="links">
      <a href="/production/" class="link-card">
        <div class="link-icon">🏭</div>
        <div class="link-content">
          <div class="link-title">Production Reports</div>
          <div class="link-desc">Official weekly project reports</div>
        </div>
      </a>

      <a href="/pr-preview/" class="link-card">
        <div class="link-icon">🔍</div>
        <div class="link-content">
          <div class="link-title">PR Previews</div>
          <div class="link-desc">Preview reports from pull requests</div>
        </div>
      </a>
    </div>

    <footer>
      <p>
        Powered by
        <a href="https://github.com/lf-it/reporting-tool" target="_blank">
          Linux Foundation Reporting Tool
        </a>
      </p>
      <p style="margin-top: 0.5rem;">
        &copy; 2025 The Linux Foundation
      </p>
    </footer>
  </div>
</body>
</html>
ROOTHTML

  echo "✅ Root index page created"
fi

echo "✅ Index generation complete"
