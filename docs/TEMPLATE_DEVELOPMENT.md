<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Template Development Guide

> Comprehensive guide to developing and customizing Jinja2 templates for the Gerrit Reporting Tool

This guide covers template architecture, available filters, component development, and best practices for creating custom report templates.

---

## Table of Contents

- [Overview](#overview)
- [Template Architecture](#template-architecture)
- [Template Filters](#template-filters)
- [Available Data Context](#available-data-context)
- [Component System](#component-system)
- [Creating Custom Templates](#creating-custom-templates)
- [Best Practices](#best-practices)
- [Testing Templates](#testing-templates)
- [Troubleshooting](#troubleshooting)

---

## Overview

The reporting tool uses **Jinja2** templates to generate both Markdown and HTML reports. This template-based approach provides:

- **Separation of concerns** - Data collection separate from presentation
- **Flexibility** - Easy customization without code changes
- **Reusability** - Components shared across templates
- **Consistency** - Centralized formatting logic

### Template Locations

```text
src/templates/
├── html/                          # HTML templates
│   ├── base.html.j2              # Main HTML template
│   ├── components/               # Reusable HTML components
│   │   ├── data_table.html.j2
│   │   ├── info_yaml_section.html.j2
│   │   └── stats_card.html.j2
│   └── sections/                 # HTML report sections
│       ├── summary.html.j2
│       ├── repositories.html.j2
│       ├── contributors.html.j2
│       ├── organizations.html.j2
│       ├── features.html.j2
│       └── workflows.html.j2
└── markdown/                      # Markdown templates
    ├── base.md.j2                # Main Markdown template
    ├── components/               # Reusable Markdown components
    │   ├── data_table.md.j2
    │   └── info_yaml_section.md.j2
    └── sections/                 # Markdown report sections
        ├── summary.md.j2
        ├── repositories.md.j2
        ├── contributors.md.j2
        ├── organizations.md.j2
        ├── features.md.j2
        └── workflows.md.j2
```

---

## Template Architecture

### Base Templates

Each output format has a **base template** that orchestrates the complete report:

#### HTML Base Template (`html/base.html.j2`)

```jinja2
<!DOCTYPE html>
<html>
<head>
    <title>📊 {{ project_name }} - {% if project.project_type == 'github' %}GitHub{% else %}Gerrit{% endif %} Project Analysis Report</title>
    <!-- CSS and metadata -->
</head>
<body>
    <header>
        <h1>📊 {% if project.project_type == 'github' %}GitHub{% else %}Gerrit{% endif %} Project Analysis Report</h1>
        <p>{{ project_name }}</p>
    </header>

    <main>
        {% include 'html/sections/summary.html.j2' %}
        {% include 'html/sections/repositories.html.j2' %}
        {% include 'html/sections/contributors.html.j2' %}
        {% include 'html/sections/organizations.html.j2' %}
        {% include 'html/sections/features.html.j2' %}
        {% include 'html/sections/workflows.html.j2' %}

        {# INFO.yaml sections rendered inline #}
        {% if info_yaml_data %}
            {% include 'html/components/info_yaml_section.html.j2' %}
        {% endif %}
    </main>

    <footer>
        <p>Generated with ❤️ by Release Engineering</p>
    </footer>
</body>
</html>
```

#### Markdown Base Template (`markdown/base.md.j2`)

```jinja2
# 📊 {% if project.project_type == 'github' %}GitHub{% else %}Gerrit{% endif %} Project Analysis Report

**Project:** {{ project_name }}

{% include 'markdown/sections/summary.md.j2' %}
{% include 'markdown/sections/repositories.md.j2' %}
{% include 'markdown/sections/contributors.md.j2' %}
{% include 'markdown/sections/organizations.md.j2' %}
{% include 'markdown/sections/features.md.j2' %}
{% include 'markdown/sections/workflows.md.j2' %}

{% if info_yaml_data %}
{% include 'markdown/components/info_yaml_section.md.j2' %}
{% endif %}

---

_Generated with ❤️ by Release Engineering_
```

### Section Templates

Each section template focuses on rendering a specific part of the report:

```jinja2
{# repositories.html.j2 example #}
<section id="repositories">
    <h2>📊 Gerrit Projects</h2>

    {% set columns = [
        {'key': 'repository_name', 'label': 'Repository', 'sortable': true},
        {'key': 'total_commits', 'label': 'Commits', 'format': 'number'},
        {'key': 'total_lines_added', 'label': 'Lines Added', 'format': 'loc'},
        {'key': 'activity_status', 'label': 'Status', 'format': 'status_emoji'}
    ] %}

    {% include 'html/components/data_table.html.j2' with context %}
</section>
```

---

## Template Filters

Filters transform data for display. All filters are registered globally and available in all templates.

### Core Formatting Filters

#### `format_number` - Number Abbreviation

Formats large numbers with K/M/B abbreviations.

```jinja2
{{ 1234 | format_number }}          {# → "1.2K" #}
{{ 1234567 | format_number }}       {# → "1.2M" #}
{{ 1234567890 | format_number }}    {# → "1.2B" #}
{{ 42 | format_number }}            {# → "42" (< 1000) #}
```

**Usage:**

- Commit counts
- LOC totals
- Large metrics

---

#### `format_loc` - Lines of Code with '+' Prefix

Formats LOC values with a '+' prefix for clarity.

```jinja2
{{ 12345 | format_loc }}     {# → "+12.3K" #}
{{ 500 | format_loc }}       {# → "+500" #}
{{ 0 | format_loc }}         {# → "+0" #}
```

**Usage:**

- Lines added columns
- LOC metrics
- Diff statistics

**New in P4** ✨

---

#### `format_percentage` - Percentage Formatting

Formats percentages with 1 decimal place. Supports both pre-calculated and calculated percentages.

```jinja2
{# Pre-calculated percentage #}
{{ 75.5 | format_percentage }}                    {# → "75.5%" #}

{# Calculate from numerator/denominator #}
{{ format_percentage(25, 100) }}                  {# → "25.0%" #}
{{ format_percentage(1, 3) }}                     {# → "33.3%" #}
```

**Usage:**

- Activity percentages
- Distribution metrics
- Contribution shares

**Enhanced in P4** ✨

---

#### `format_date` - Date Formatting

Formats ISO timestamps as human-readable dates.

```jinja2
{{ "2025-01-15T10:30:00Z" | format_date }}   {# → "2025-01-15" #}
{{ commit.date | format_date }}              {# → "2024-12-20" #}
```

**Usage:**

- Last commit dates
- Report timestamps
- Activity dates

---

#### `status_emoji` - Status to Emoji

Maps activity status strings to emoji indicators.

```jinja2
{{ "active" | status_emoji }}       {# → "✅" #}
{{ "stale" | status_emoji }}        {# → "☑️" #}
{{ "inactive" | status_emoji }}     {# → "🛑" #}
{{ "unknown" | status_emoji }}      {# → "❓" #}
```

**Status Mappings:**

- `active` → ✅ (green checkmark)
- `stale` → ☑️ (ballot box with check)
- `inactive` → 🛑 (stop sign)
- `unknown` / default → ❓ (question mark)

**Usage:**

- Repository status column
- Activity indicators
- Health metrics

**New in P4** ✨

---

#### `format_feature_name` - Feature Name Formatting

Formats feature identifiers as human-readable names.

```jinja2
{{ "ci_cd" | format_feature_name }}              {# → "CI/CD" #}
{{ "documentation" | format_feature_name }}      {# → "Documentation" #}
{{ "dependency_management" | format_feature_name }}  {# → "Dependency Management" #}
```

**Usage:**

- Feature matrix
- Feature detection results
- Configuration labels

---

### Filter Usage Examples

#### Example 1: Repository Table

```jinja2
{% set columns = [
    {'key': 'repository_name', 'label': 'Repository'},
    {'key': 'total_commits', 'label': 'Commits', 'format': 'number'},
    {'key': 'total_lines_added', 'label': 'Lines Added', 'format': 'loc'},
    {'key': 'last_commit_date', 'label': 'Last Commit', 'format': 'date'},
    {'key': 'activity_status', 'label': 'Status', 'format': 'status_emoji'}
] %}
```

#### Example 2: Summary Statistics

```jinja2
<div class="stat">
    <h3>Total Commits</h3>
    <p class="value">{{ total_commits | format_number }}</p>
</div>

<div class="stat">
    <h3>Lines Added</h3>
    <p class="value">{{ total_lines_added | format_loc }}</p>
</div>

<div class="stat">
    <h3>Active Repos</h3>
    <p class="value">{{ format_percentage(active_count, total_count) }}</p>
</div>
```

#### Example 3: Manual Filter Application

```jinja2
{# In table cells #}
<td>{{ row.total_lines_added | format_loc }}</td>
<td>{{ row.activity_status | status_emoji }}</td>
<td>{{ row.last_commit_date | format_date }}</td>
```

---

## Available Data Context

The template context contains all report data and metadata:

### Top-Level Variables

```python
{
    'project_name': str,              # e.g., "ONAP", "O-RAN-SC"
    'report_date': str,               # ISO timestamp
    'config': dict,                   # Configuration object
    'repositories': list[dict],       # Repository data
    'contributors': list[dict],       # Contributor data
    'organizations': list[dict],      # Organization data
    'features': list[dict],           # Feature matrix
    'workflows': list[dict],          # CI/CD workflow data
    'summary': dict,                  # Summary statistics
    'info_yaml_data': dict | None,   # INFO.yaml data (optional)
}
```

### Repository Data Structure

```python
{
    'repository_name': str,
    'total_commits': int,
    'total_lines_added': int,
    'total_lines_deleted': int,
    'contributor_count': int,
    'first_commit_date': str,         # ISO timestamp
    'last_commit_date': str,          # ISO timestamp
    'activity_status': str,           # "active" | "stale" | "inactive"
    'features': dict,                 # Feature detection results
}
```

### Contributor Data Structure

```python
{
    'author_name': str,
    'author_email': str,
    'organization': str,              # Domain-based organization
    'total_commits': int,
    'total_lines_added': int,
    'total_lines_deleted': int,
    'repository_count': int,
    'avg_loc_per_commit': float,
}
```

### Organization Data Structure

```python
{
    'organization': str,
    'contributor_count': int,
    'total_commits': int,
    'total_lines_added': int,
    'repository_count': int,
    'avg_loc_per_commit': float,
}
```

### Feature Data Structure

```python
{
    'repository_name': str,
    'features': {
        'ci_cd': bool,
        'documentation': bool,
        'dependency_management': bool,
        'code_quality': bool,
        'security': bool,
        'testing': bool,
    }
}
```

### Summary Data Structure

```python
{
    'total_repositories': int,
    'total_commits': int,
    'total_contributors': int,
    'total_organizations': int,
    'total_lines_added': int,
    'active_repositories': int,
    'active_percentage': float,       # Pre-calculated
}
```

---

## Component System

Components are reusable template fragments included by sections.

### Data Table Component

The most important component for displaying tabular data.

**Location:** `components/data_table.html.j2` / `components/data_table.md.j2`

**Parameters:**

- `columns` - Column definitions (list of dicts)
- `rows` - Data rows (list of dicts)
- `table_id` - Optional table ID for JavaScript

**Column Definition:**

```python
{
    'key': str,           # Data key in row dict
    'label': str,         # Column header text
    'format': str,        # Optional: 'number', 'loc', 'date', 'percentage', 'status_emoji'
    'sortable': bool,     # Optional: Enable sorting (HTML only)
    'class': str,         # Optional: CSS class
}
```

**Usage Example:**

```jinja2
{% set columns = [
    {'key': 'name', 'label': 'Name', 'sortable': true},
    {'key': 'commits', 'label': 'Commits', 'format': 'number'},
    {'key': 'loc', 'label': 'LOC', 'format': 'loc'},
    {'key': 'status', 'label': 'Status', 'format': 'status_emoji'}
] %}

{% set rows = repositories %}

{% include 'html/components/data_table.html.j2' with context %}
```

**Supported Format Types:**

<!-- markdownlint-disable MD060 -->

| Format         | Filter Applied      | Example Output |
| -------------- | ------------------- | -------------- |
| `number`       | `format_number`     | "1.2K"         |
| `loc`          | `format_loc`        | "+12.3K"       |
| `date`         | `format_date`       | "2025-01-15"   |
| `percentage`   | `format_percentage` | "75.5%"        |
| `status_emoji` | `status_emoji`      | "✅"           |
| (none)         | Raw value           | "example"      |

<!-- markdownlint-enable MD060 -->

---

### INFO.yaml Section Component

Renders INFO.yaml committer activity data.

**Location:** `components/info_yaml_section.html.j2` / `components/info_yaml_section.md.j2`

**Context Required:**

- `info_yaml_data` - INFO.yaml report data

**Usage:**

```jinja2
{% if info_yaml_data %}
    {% include 'html/components/info_yaml_section.html.j2' %}
{% endif %}
```

---

### Stats Card Component (HTML only)

Displays a summary statistic card.

**Location:** `components/stats_card.html.j2`

**Parameters:**

- `title` - Card title
- `value` - Main value to display
- `icon` - Optional emoji icon

**Usage:**

```jinja2
{% include 'html/components/stats_card.html.j2' with {
    'title': 'Total Commits',
    'value': total_commits | format_number,
    'icon': '📝'
} %}
```

---

## Creating Custom Templates

### Step 1: Create Template File

Create a new template file in the appropriate directory:

```bash
# For HTML
touch src/templates/html/sections/my_section.html.j2

# For Markdown
touch src/templates/markdown/sections/my_section.md.j2
```

### Step 2: Define Template Structure

```jinja2
{# my_section.html.j2 #}
<section id="my-section">
    <h2>🎯 My Custom Section</h2>

    <p>Custom content here</p>

    {% if my_data %}
        {% set columns = [
            {'key': 'name', 'label': 'Name'},
            {'key': 'value', 'label': 'Value', 'format': 'number'}
        ] %}

        {% set rows = my_data %}

        {% include 'html/components/data_table.html.j2' with context %}
    {% endif %}
</section>
```

### Step 3: Include in Base Template

Add the include directive to the base template:

```jinja2
{# base.html.j2 #}
<main>
    {% include 'html/sections/summary.html.j2' %}
    {% include 'html/sections/my_section.html.j2' %}  {# ← Add here #}
    {% include 'html/sections/repositories.html.j2' %}
    ...
</main>
```

### Step 4: Provide Data Context

Ensure your custom data is available in the template context:

```python
# In src/rendering/context.py
def build(self) -> dict[str, Any]:
    context = {
        'project_name': self.data.get('project_name'),
        'my_data': self._prepare_my_data(),  # ← Add data preparation
        ...
    }
    return context

def _prepare_my_data(self) -> list[dict]:
    """Prepare custom section data."""
    return [
        {'name': 'Item 1', 'value': 100},
        {'name': 'Item 2', 'value': 200},
    ]
```

---

## Best Practices

### 1. Use Consistent Section Structure

```jinja2
<section id="section-name">
    <h2>🎯 Section Title</h2>

    {# Optional: Section description #}
    <p>Description of what this section shows</p>

    {# Main content #}
    {% include 'components/data_table.html.j2' %}

    {# Optional: Footer notes #}
    <p class="note">Additional notes</p>
</section>
```

### 2. Always Use Components for Tables

❌ **Don't:**

```jinja2
<table>
    <tr>
        <th>Name</th>
        <th>Value</th>
    </tr>
    {% for item in items %}
    <tr>
        <td>{{ item.name }}</td>
        <td>{{ item.value }}</td>
    </tr>
    {% endfor %}
</table>
```

✅ **Do:**

```jinja2
{% set columns = [
    {'key': 'name', 'label': 'Name'},
    {'key': 'value', 'label': 'Value', 'format': 'number'}
] %}
{% include 'html/components/data_table.html.j2' with context %}
```

### 3. Apply Filters Consistently

Use format specifications in column definitions:

```jinja2
{% set columns = [
    {'key': 'commits', 'label': 'Commits', 'format': 'number'},
    {'key': 'loc', 'label': 'LOC', 'format': 'loc'},
    {'key': 'date', 'label': 'Date', 'format': 'date'},
    {'key': 'status', 'label': 'Status', 'format': 'status_emoji'}
] %}
```

### 4. Use Emoji Consistently

Match emoji usage across HTML and Markdown:

```jinja2
<h2>📈 Summary</h2>              {# Summary section #}
<h2>📊 Gerrit Projects</h2>      {# Repositories #}
<h2>👥 Top Contributors</h2>     {# Contributors #}
<h2>🏢 Top Organizations</h2>    {# Organizations #}
<h2>🔧 Repository Feature Matrix</h2>  {# Features #}
<h2>🏁 Deployed CI/CD Jobs</h2>  {# Workflows #}
```

### 5. Handle Missing Data Gracefully

```jinja2
{% if data %}
    {# Show table #}
    {% include 'components/data_table.html.j2' %}
{% else %}
    <p class="empty-state">No data available</p>
{% endif %}
```

### 6. Use Descriptive Variable Names

```jinja2
{# Good #}
{% set repository_columns = [...] %}
{% set contributor_rows = top_contributors %}

{# Bad #}
{% set cols = [...] %}
{% set data = contributors %}
```

### 7. Keep Templates DRY

Extract repeated patterns into components:

```jinja2
{# Before: Repeated code #}
<div class="stat">
    <h3>Commits</h3>
    <p>{{ total_commits | format_number }}</p>
</div>
<div class="stat">
    <h3>Contributors</h3>
    <p>{{ total_contributors | format_number }}</p>
</div>

{# After: Using component #}
{% include 'components/stats_card.html.j2' with {'title': 'Commits', 'value': total_commits | format_number} %}
{% include 'components/stats_card.html.j2' with {'title': 'Contributors', 'value': total_contributors | format_number} %}
```

---

## Testing Templates

### Manual Testing

Generate a test report:

```bash
# Quick test with minimal data
bash testing/quick-test.sh

# Full test with ONAP data
bash testing/local-testing.sh ONAP

# Check both HTML and Markdown outputs
open report.html
cat report.md
```

### Visual Verification Checklist

- [ ] All sections render without errors
- [ ] Filters are applied correctly
- [ ] Tables are formatted consistently
- [ ] Emoji display correctly
- [ ] Numbers are abbreviated appropriately
- [ ] Dates are formatted properly
- [ ] Status indicators show correct emoji
- [ ] LOC values have '+' prefix
- [ ] Responsive layout works (HTML)
- [ ] Tables are sortable (HTML)

### Automated Testing

Templates are tested indirectly through integration tests:

```bash
# Run integration tests
uv run pytest tests/integration/

# Check for template rendering errors
uv run pytest tests/integration/test_report_generation.py -v
```

### Template Syntax Validation

Check for Jinja2 syntax errors:

```python
from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('src/templates'))
template = env.get_template('html/base.html.j2')
# No exception = valid syntax
```

---

## Troubleshooting

### Template Not Found

**Error:** `jinja2.exceptions.TemplateNotFound: html/sections/my_section.html.j2`

**Solutions:**

1. Check file path is correct relative to `src/templates/`
2. Verify file extension is `.j2`
3. Ensure template loader is configured correctly

---

### Undefined Variable

**Error:** `jinja2.exceptions.UndefinedError: 'my_variable' is undefined`

**Solutions:**

1. Check variable is provided in context (see `src/rendering/context.py`)
2. Use default filter: `{{ my_variable | default('N/A') }}`
3. Check for typos in variable name

---

### Filter Not Applied

**Problem:** Filter not working in table cells

**Solution:** Ensure format is specified in column definition:

```jinja2
{# Wrong - filter in template #}
<td>{{ row.value | format_number }}</td>

{# Correct - format in column definition #}
{% set columns = [{'key': 'value', 'format': 'number'}] %}
```

---

### Missing Data in Table

**Problem:** Table shows empty cells

**Solutions:**

1. Check data key matches column definition
2. Verify data is in context
3. Use default value: `{{ row.get('key', 'N/A') }}`

---

### Emoji Not Displaying

**Problem:** Emoji showing as boxes or question marks

**Solutions:**

1. Ensure UTF-8 encoding: `<meta charset="UTF-8">`
2. Use Unicode emoji (not images)
3. Test in modern browser

---

## Additional Resources

### Related Documentation

- [Configuration Guide](CONFIGURATION.md) - Template configuration options
- [Developer Guide](DEVELOPER_GUIDE.md) - Architecture and API reference
- [Testing Guide](TESTING.md) - Comprehensive testing documentation

### Template Examples

- `src/templates/html/` - Complete HTML template examples
- `src/templates/markdown/` - Complete Markdown template examples
- `testing/` - Test scripts that generate example reports

### Jinja2 Documentation

- [Jinja2 Template Designer Documentation](https://jinja.palletsprojects.com/templates/)
- [Jinja2 API Documentation](https://jinja.palletsprojects.com/api/)

---

## Summary

### Key Takeaways

1. **Use components** for reusable elements (especially tables)
2. **Apply filters** through column definitions, not inline
3. **Keep templates DRY** - extract repeated patterns
4. **Handle missing data** gracefully with defaults
5. **Test thoroughly** with both minimal and full datasets
6. **Match structure** between HTML and Markdown templates

### Quick Reference

**Common Filters:**

- `format_number` - Large numbers → "1.2K"
- `format_loc` - LOC → "+12.3K"
- `format_percentage` - Percentage → "75.5%"
- `format_date` - Date → "2025-01-15"
- `status_emoji` - Status → "✅"

**Common Components:**

- `data_table` - Sortable data tables
- `info_yaml_section` - INFO.yaml data
- `stats_card` - Summary statistics (HTML)

**Test Commands:**

```bash
bash testing/quick-test.sh        # Quick test
bash testing/local-testing.sh     # Full test
open report.html                  # View HTML
cat report.md                     # View Markdown
```

---

_For questions or issues, see [Troubleshooting Guide](TROUBLESHOOTING.md) or open an issue on GitHub._
