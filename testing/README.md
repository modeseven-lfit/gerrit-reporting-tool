<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Local Testing Guide

This directory contains scripts for local testing of the reporting tool with real Gerrit server data.

## Overview

The `local-testing.sh` script automates the following workflow:

1. **Check for existing repositories** - Reuses already cloned repositories if present
2. **Clone repositories** (if needed) from Gerrit servers using `gerrit-clone` CLI tool
3. **Generate reports** using the `project-reporting-tool` on the cloned repositories
4. **Output results** to `/tmp/reports` for manual review

## Prerequisites

### Required Software

- **uv** - Package manager and tool runner

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- **git** - Git version control system

  ```bash
  # Pre-installed on most systems
  git --version
  ```

- **jq** - JSON parser for project metadata

  ```bash
  brew install jq  # macOS
  sudo apt-get install jq  # Debian/Ubuntu
  ```

### SSH Key Configuration

The script requires SSH access to clone the info-master repository from `gerrit.linuxfoundation.org`.

**Option 1: Use existing SSH key (recommended)**

```bash
# Copy your Gerrit SSH key to the expected location
cp ~/.ssh/id_rsa ~/.ssh/gerrit.linuxfoundation.org
# Or create a symlink
ln -s ~/.ssh/id_rsa ~/.ssh/gerrit.linuxfoundation.org
```

**Option 2: Set environment variable (CI/CD mode)**

```bash
export LF_GERRIT_INFO_MASTER_SSH_KEY="$(cat ~/.ssh/id_rsa)"
```

The script will automatically:

- Check for `LF_GERRIT_INFO_MASTER_SSH_KEY` environment variable first
- Fall back to `~/.ssh/gerrit.linuxfoundation.org` if not set
- Exit with error if the script cannot find either location

### Disk Space

Ensure you have enough disk space in `/tmp`:

- **ONAP**: ~50-100 GB (varies based on number of active repositories)
- **OpenDaylight**: ~10-20 GB (varies based on number of active repositories)

Check available space:

```bash
df -h /tmp
```

### API Access (Optional but Recommended)

By default, reports use **local git data**. To include GitHub workflow status, Gerrit metadata, and Jenkins CI/CD information, you need to configure API access.

**Quick setup:**

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```

**📖 See [API_ACCESS.md](API_ACCESS.md) for complete API configuration guide**

Without API tokens, reports will be fast (~10-20 seconds) but will **NOT** include:

- ✗ GitHub workflow status
- ✗ Gerrit repository metadata
- ✗ Jenkins CI/CD information

With API tokens, reports take longer (~5-10 minutes) but include complete data.

## Report Comparison Workflow

The testing script now automatically:

1. **Copies all generated reports** from `/tmp/reports` to `testing/reports/` (preserving directory structure)
2. **Downloads production reports** from GitHub Pages into each project directory as `production-report.html`

This creates a convenient side-by-side comparison structure:

```bash
testing/reports/
├── ONAP/
│   ├── report.html              # Latest test run
│   ├── production-report.html   # Current production baseline (from GitHub Pages)
│   ├── theme.css                # Shared stylesheet (both reports can use it)
│   ├── report_raw.json          # Complete test data
│   ├── report.md                # Markdown report
│   └── config_resolved.json     # Configuration used
│
└── Opendaylight/
    ├── report.html              # Latest test run
    ├── production-report.html   # Current production baseline
    ├── theme.css                # Shared stylesheet
    ├── report_raw.json
    ├── report.md
    └── config_resolved.json
```

**Benefits:**

- CSS and assets share a location, so both reports render properly in the browser
- Easy side-by-side comparison in separate browser tabs
- All reports in one location for review
- Production baseline automatically updated from GitHub Pages

## Quick Start

Run the testing script:

```bash
cd project-reporting-tool/testing
./local-testing.sh
```

The script will:

1. ✅ Load project metadata from `projects.json`
2. ✅ Check prerequisites (uv, git, jq)
3. 🔑 Verify SSH key for info-master access
4. 🔍 Check API configuration (GitHub/Gerrit/Jenkins)
5. 📁 Create output directories
6. 📥 Clone ONAP repositories to `/tmp/gerrit.onap.org` (if not already present)
7. 📥 Clone OpenDaylight repositories to `/tmp/git.opendaylight.org` (if not already present)
8. 📊 Generate ONAP report to `/tmp/reports/ONAP`
9. 📊 Generate OpenDaylight report to `/tmp/reports/Opendaylight`
10. 📋 Display summary of results

**Notes:**

- The script uses project metadata from `projects.json` to configure Gerrit/Jenkins hosts automatically
- SSH key required for info-master access (see SSH Key Configuration above)
- The script preserves existing cloned repositories to save time on later runs
- The script cleans and regenerates report directories
- The script will warn you if API integrations are not configured
- See [API_ACCESS.md](API_ACCESS.md) to enable GitHub/Gerrit/Jenkins API access

## Output Structure

After successful execution, you'll have reports in two locations:

### 1. Source Reports (generated in /tmp)

```bash
/tmp/
├── gerrit.onap.org/              # Cloned ONAP repositories
│   ├── aai/
│   ├── ccsdk/
│   ├── dcaegen2/
│   └── ...
│
├── git.opendaylight.org/         # Cloned OpenDaylight repositories
│   ├── aaa/
│   ├── controller/
│   ├── netconf/
│   └── ...
│
└── reports/                      # Initial report output
    ├── ONAP/
    │   ├── report_raw.json
    │   ├── report.md
    │   ├── report.html
    │   ├── theme.css
    │   ├── config_resolved.json
    │   └── ONAP_report_bundle.zip
    │
    └── Opendaylight/
        ├── report_raw.json
        ├── report.md
        ├── report.html
        ├── theme.css
        ├── config_resolved.json
        └── Opendaylight_report_bundle.zip
```

### 2. Testing Directory (copied for comparison)

```bash
testing/reports/                  # Copied for easy comparison
├── ONAP/
│   ├── report.html              # Latest test run
│   ├── production-report.html   # Downloaded from GitHub Pages
│   ├── theme.css                # Shared stylesheet
│   ├── report_raw.json          # Complete test data
│   ├── report.md                # Markdown report
│   ├── config_resolved.json     # Applied configuration
│   └── ONAP_report_bundle.zip   # Bundle with all files
│
└── Opendaylight/
    ├── report.html              # Latest test run
    ├── production-report.html   # Downloaded from GitHub Pages
    ├── theme.css                # Shared stylesheet
    ├── report_raw.json
    ├── report.md
    ├── config_resolved.json
    └── Opendaylight_report_bundle.zip
```

## Configuration

### Project Metadata

The script uses `projects.json` to configure project-specific settings:

```json
[
  {
    "project": "ONAP",
    "gerrit": "gerrit.onap.org",
    "jenkins": "jenkins.onap.org"
  },
  {
    "project": "Opendaylight",
    "gerrit": "git.opendaylight.org",
    "jenkins": "jenkins.opendaylight.org"
  }
]
```

To add more projects, edit `testing/projects.json` with:

- `project` - Project name
- `gerrit` - Gerrit server hostname
- `jenkins` - Jenkins server hostname (optional)
- `github` - GitHub organization name (optional)

### Customizing Base Directories

Edit the script variables at the top of `local-testing.sh`:

```bash
# Base directories
CLONE_BASE_DIR="/tmp"
REPORT_BASE_DIR="/tmp/reports"

# SSH key location
SSH_KEY_PATH="${HOME}/.ssh/gerrit.linuxfoundation.org"
```

### gerrit-clone Options

The script uses these `gerrit-clone` options:

- `--https` - Clone via HTTPS (no SSH keys required)
- `--skip-archived` - Skip archived/inactive repositories
- `--threads 4` - Use 4 concurrent threads
- `--clone-timeout 600` - 10-minute timeout per repository
- `--retry-attempts 3` - Retry failed clones up to 3 times
- `--move-conflicting` - Move conflicting files to allow nested repos
- `--verbose` - Show detailed progress

To change these, edit the `clone_onap()` and `clone_opendaylight()` functions in the script.

### project-reporting-tool Options

The script uses these `project-reporting-tool` options:

- `--cache` - Enable caching for better performance
- `--workers 4` - Use 4 concurrent workers

To change these, edit the `generate_onap_report()` and `generate_opendaylight_report()` functions.

## Reviewing Reports

### Markdown Reports

Quick, human-readable overview:

```bash
# ONAP report
less /tmp/reports/ONAP/report.md

# OpenDaylight report
less /tmp/reports/OpenDaylight/report.md
```

### HTML Reports

Interactive reports with sortable tables (use testing/reports for side-by-side comparison):

```bash
# Compare ONAP reports (macOS)
open testing/reports/ONAP/report.html
open testing/reports/ONAP/production-report.html

# Compare OpenDaylight reports (macOS)
open testing/reports/Opendaylight/report.html
open testing/reports/Opendaylight/production-report.html

# Linux
xdg-open testing/reports/ONAP/report.html &
xdg-open testing/reports/ONAP/production-report.html &
```

**Tip:** Open both reports in separate browser tabs to compare side-by-side. The CSS and all assets will load properly since they're in the same directory.

### JSON Data

Complete structured data for programmatic analysis:

```bash
# ONAP data
jq '.' testing/reports/ONAP/report_raw.json | less

# OpenDaylight data
jq '.' testing/reports/Opendaylight/report_raw.json | less

# Compare specific metrics
jq '.organizations[] | select(.domain == "est.tech")' testing/reports/ONAP/report_raw.json
```

## Troubleshooting

### SSH Key Issues

If you see "❌ SSH key not found":

1. **Copy your SSH key to the expected location**:

   ```bash
   cp ~/.ssh/id_rsa ~/.ssh/gerrit.linuxfoundation.org
   ```

2. **Or set environment variable**:

   ```bash
   export LF_GERRIT_INFO_MASTER_SSH_KEY="$(cat ~/.ssh/id_rsa)"
   ```

3. **Test SSH access**:

   ```bash
   ssh -p 29418 gerrit.linuxfoundation.org gerrit version
   ```

### Clone Failures

If cloning fails:

1. **Check network connectivity**:

   ```bash
   ping gerrit.onap.org
   ping git.opendaylight.org
   ```

2. **Verify server accessibility**:

   ```bash
   curl -I https://gerrit.onap.org
   curl -I https://git.opendaylight.org
   ```

3. **Check disk space**:

   ```bash
   df -h /tmp
   ```

4. **Review clone logs** - The script outputs detailed progress

### Report Generation Failures

If report generation fails:

1. **Verify repository cloning**:

   ```bash
   ls -la /tmp/gerrit.onap.org/
   ls -la /tmp/git.opendaylight.org/
   ```

2. **Check for valid git repositories**:

   ```bash
   find /tmp/gerrit.onap.org -name ".git" -type d | head -5
   ```

3. **Run with verbose output** - Already enabled in the script

4. **Check the project-reporting-tool dependencies**:

   ```bash
   cd project-reporting-tool
   uv sync
   ```

### Out of Disk Space

If you run out of disk space:

1. **Clean up previous test runs**:

   ```bash
   rm -rf /tmp/gerrit.onap.org
   rm -rf /tmp/git.opendaylight.org
   rm -rf /tmp/reports
   ```

2. **Use a different directory** with more space:

   ```bash
   # Edit local-testing.sh
   CLONE_BASE_DIR="/path/to/larger/disk"
   REPORT_BASE_DIR="/path/to/larger/disk/reports"
   ```

3. **Clone with shallow depth** (edit the script):

   ```bash
   uvx gerrit-clone \
       --depth 1 \
       # ... other options
   ```

## Manual Testing

### Test Individual Steps

You can run individual steps manually:

#### 1. Clone ONAP

```bash
uvx gerrit-clone clone \
    --host gerrit.onap.org \
    --output-path /tmp \
    --https \
    --skip-archived \
    --threads 4 \
    --verbose
```

#### 2. Clone OpenDaylight

```bash
uvx gerrit-clone clone \
    --host git.opendaylight.org \
    --output-path /tmp \
    --https \
    --skip-archived \
    --threads 4 \
    --verbose
```

#### 3. Generate ONAP report

```bash
cd project-reporting-tool
uv run project-reporting-tool generate \
    --project "ONAP" \
    --repos-path /tmp/gerrit.onap.org \
    --output-dir /tmp/reports \
    --cache \
    --workers 4
```

#### 4. Generate OpenDaylight report

```bash
cd project-reporting-tool
uv run project-reporting-tool generate \
    --project "OpenDaylight" \
    --repos-path /tmp/git.opendaylight.org \
    --output-dir /tmp/reports \
    --cache \
    --workers 4
```

## Cleanup

### Remove Test Data

To clean up all test data:

```bash
rm -rf /tmp/gerrit.onap.org
rm -rf /tmp/git.opendaylight.org
rm -rf /tmp/reports
```

Or use the cleanup script:

```bash
cd project-reporting-tool/testing
./cleanup.sh
```

### Automatic Cleanup

The script cleans up **report directories** at the start of each run. The script preserves and reuses cloned repositories to save time. To force a fresh clone, remove the cached directories:

```bash
rm -rf /tmp/gerrit.onap.org
rm -rf /tmp/git.opendaylight.org
```

## Advanced Usage

### Test with More Projects

The script processes ONAP and Opendaylight by default. To test other projects:

1. **Edit `local-testing.sh`** and change the projects array:

   ```bash
   # Change this line in the main() function:
   local projects=("ONAP" "Opendaylight" "O-RAN-SC" "AGL")
   ```

2. **Or test specific projects manually**:

   ```bash
   # Clone O-RAN-SC
   uvx gerrit-clone clone \
       --host gerrit.o-ran-sc.org \
       --output-path /tmp/gerrit.o-ran-sc.org

   # Generate report
   cd project-reporting-tool
   uv run project-reporting-tool generate \
       --project "O-RAN-SC" \
       --repos-path /tmp/gerrit.o-ran-sc.org \
       --output-dir /tmp/reports
   ```

### Use SSH Instead of HTTPS

If you have SSH keys configured:

```bash
# Remove --https and add SSH options
uvx gerrit-clone clone \
    --host gerrit.onap.org \
    --output-path /tmp \
    --ssh-user your-username \
    --ssh-private-key ~/.ssh/id_rsa \
    --threads 4 \
    --verbose
```

### Different Report Formats

Generate specific report formats:

```bash
uv run project-reporting-tool generate \
    --project "ONAP" \
    --repos-path /tmp/gerrit.onap.org \
    --output-dir /tmp/reports/onap \
    --output-format json  # Generate JSON format (options: json, md, html, all)
```

## Performance Tips

1. **Increase threads** for faster cloning (if network allows):

   ```bash
   --threads 8
   ```

2. **Use shallow clones** for faster initial clone:

   ```bash
   --depth 1
   ```

3. **Enable caching** for repeated report generation:

   ```bash
   --cache
   ```

4. **Increase workers** for faster report generation:

   ```bash
   --workers 8
   ```

5. **Reuse cloned repositories** - The script automatically preserves cloned repos between runs, saving significant time on later executions.

6. **Enable API access** - Set `GITHUB_TOKEN` and other API credentials for complete data. See [API_ACCESS.md](API_ACCESS.md).

## Project Metadata Reference

The `projects.json` file contains metadata for all supported Linux Foundation projects:

- **O-RAN-SC** - gerrit.o-ran-sc.org, jenkins.o-ran-sc.org
- **ONAP** - gerrit.onap.org, jenkins.onap.org
- **Opendaylight** - git.opendaylight.org, jenkins.opendaylight.org
- **AGL** - gerrit.automotivelinux.org, build.automotivelinux.org
- **OPNFV** - gerrit.opnfv.org
- **FDio** - gerrit.fd.io, jenkins.fd.io
- **LF Broadband** - gerrit.lfbroadband.org, jenkins.lfbroadband.org
- **Linux Foundation** - gerrit.linuxfoundation.org

This metadata automatically configures API endpoints for each project.

## See Also

- [API Access Configuration](API_ACCESS.md) - **Enable GitHub/Gerrit/Jenkins APIs**
- [gerrit-clone documentation](https://github.com/lfreleng-actions/gerrit-clone-action)
- [project-reporting-tool documentation](../README.md)
- [Configuration guide](../docs/CONFIGURATION.md)
- [Performance guide](../docs/PERFORMANCE.md)

---

## Projects Configuration (projects.json)

### Security Notice

**IMPORTANT:** The `testing/projects.json` file is `.gitignored` because it may contain sensitive credentials.

- ✅ **Local testing:** Use actual credentials in `testing/projects.json` (raw JSON)
- ✅ **Production:** Credentials are in GitHub Secrets `PROJECTS_JSON` (**base64-encoded**)
- ❌ **Never commit** `testing/projects.json` to the repository

> **Note:** The local `testing/projects.json` file uses raw JSON format, but the
> GitHub `PROJECTS_JSON` secret must be **base64-encoded** to prevent console log
> redaction issues. See the [Production Setup](#production-setup-github-actions)
> section below.

### Schema

The `projects.json` file defines project configurations. See `projects.json.example` for the complete schema.

**Basic/Gerrit project:**

```json
{
  "project": "Project Name",
  "slug": "project-slug",
  "gerrit": "gerrit.example.org",
  "jenkins": "jenkins.example.org"
}
```

**Project with Jenkins authentication:**

```json
{
  "project": "Aether",
  "slug": "aether",
  "github": "opennetworkinglab",
  "jenkins": "jenkins.aetherproject.org",
  "jenkins_user": "your-jenkins-username",
  "jenkins_token": "your-jenkins-api-token"
}
```

**GitHub project:**

```json
{
  "project": "GitHub Project",
  "slug": "gh-project",
  "github": "github-org-name"
}
```

### Fields Reference

| Field             | Required | Description                          |
| ----------------- | -------- | ------------------------------------ |
| `project`         | Yes      | Human-readable project name          |
| `slug`            | Yes      | Short identifier (URL-safe)          |
| `gerrit`          | No       | Gerrit server hostname               |
| `jenkins`         | No       | Jenkins server hostname              |
| `jenkins_user`    | No       | Jenkins username for authentication  |
| `jenkins_token`   | No       | Jenkins API token for authentication |
| `github`          | No       | GitHub organization name             |
| `jjb_attribution` | No       | JJB configuration object             |

### Setup for Local Testing

1. **Copy the example file:**

   ```bash
   cp testing/projects.json.example testing/projects.json
   ```

2. **Add your projects** with actual credentials:

   ```bash
   vim testing/projects.json
   ```

3. **Verify it's .gitignored:**

   ```bash
   git status testing/projects.json
   # Should show: "No changes" or not listed
   ```

### Production Setup (GitHub Actions)

In production, the `PROJECTS_JSON` secret contains the same JSON structure,
but **must be base64-encoded** to prevent console log redaction issues.

**Encoding your projects.json for production:**

```bash
# Encode your local projects.json to base64
cat testing/projects.json | base64

# On macOS (to avoid line wrapping):
cat testing/projects.json | base64 -b 0

# Verify the encoding:
echo "YOUR_BASE64_STRING" | base64 -d | jq .
```

**Setup steps:**

1. Create your `projects.json` file with credentials (locally)
2. Encode it to base64: `cat testing/projects.json | base64`
3. Go to repository secrets: <https://github.com/modeseven-lfit/test-project-reporting-tool/settings/secrets/actions>
4. Update `PROJECTS_JSON` secret with the **base64-encoded** value (not raw JSON)

**Example raw JSON (before encoding):**

```json
[
  {
    "project": "Aether",
    "slug": "aether",
    "github": "opennetworkinglab",
    "jenkins": "jenkins.aetherproject.org",
    "jenkins_user": "actual-username-here",
    "jenkins_token": "actual-token-here"
  }
]
```

The GitHub workflow automatically passes credentials from the JSON to environment variables.

### Validation

A pre-commit hook checks the `testing/projects.json` file to ensure it matches the schema requirements before committing.

#### Validation Scripts

Two scripts work together to ensure `projects.json` correctness:

1. **`scripts/check-projects-json.sh`** - The schema checker
   - Checks a single `projects.json` file against the schema
   - Used by the pre-commit hook
   - Mirrors the exact validation logic from the GitHub Actions workflow

2. **`scripts/test-projects-json-checks.sh`** - The test suite
   - Tests the checker script itself
   - Runs 15 test cases with valid and invalid configurations
   - Ensures the validation logic works as expected

#### Automatic Validation (Pre-commit Hook)

The hook runs automatically when you commit changes to `testing/projects.json`:

```bash
git add testing/projects.json
git commit -m "Update projects configuration"
# Validation runs automatically
```

#### Manual Schema Check

You can manually check the file at any time:

```bash
# Check the testing projects.json
./scripts/check-projects-json.sh testing/projects.json

# Or run the pre-commit hook directly
pre-commit run check-projects-json --files testing/projects.json
```

#### Running All Schema Tests

A comprehensive test suite verifies the schema checking logic:

```bash
./scripts/test-projects-json-checks.sh
```

This tests both valid and invalid configurations to ensure the schema checks work as expected.

#### Schema Requirements

The validation checks that:

1. **JSON is valid** - No syntax errors
2. **Structure is an array** - Must be `[...]` not `{...}`
3. **Required fields exist** for each project:
   - `project` - Human-readable name
   - `slug` - Short identifier
   - At least one of `gerrit` or `github` - Data source

4. **Optional fields** you can include:
   - `jenkins` - Jenkins server hostname
   - `jenkins_user` - Jenkins username
   - `jenkins_token` - Jenkins API token
   - `jjb_attribution` - JJB configuration object

#### Troubleshooting Validation Errors

**Error: "PROJECTS_JSON contains invalid JSON"**

- Check for syntax errors (missing commas, brackets, quotes)
- Use a JSON validator: `jq . testing/projects.json`

**Error: "PROJECTS_JSON must be an array"**

- Ensure the file starts with `[` and ends with `]`

**Error: "Each project must have 'project' and 'slug' fields..."**

- Verify each project object has all required fields
- At least one of `gerrit` or `github` must be present

#### How the Matrix Works (ACTIVE_PROJECTS Approach)

The production workflow uses a secure, two-variable approach to handle secrets:

**The Problem We Solved:**

GitHub Actions automatically redacts job outputs that contain or reference secrets, even if you extract non-secret data from them. GitHub traces any data derived from a secret and redacts it, which caused:

```text
Skip output 'matrix' since it may contain secret.
Error from function 'fromJSON': empty input
```

**The Solution:**

We use **two distinct sources** to isolate secrets from the matrix:

1. **ACTIVE_PROJECTS variable** (public, no secrets):

   ```json
   ["oran", "onap", "odl", "agl", "opnfv", "fdio", "lfbroadband", "lfit", "aether"]
   ```

   - Simple array of project slugs
   - Stored as a GitHub repository **variable** (not a secret)
   - Used to build the matrix (no secret trace)

2. **PROJECTS_JSON secret** (contains credentials):
   - Full project configurations including `jenkins_user`, `jenkins_token`
   - Each job reads this directly using its slug
   - Never touches job outputs

**Workflow Steps:**

1. **Verify Job** - Validates and creates matrix:
   - Validates `PROJECTS_JSON` schema
   - Verifies all slugs in `ACTIVE_PROJECTS` exist in `PROJECTS_JSON`
   - Creates matrix from `ACTIVE_PROJECTS`: `{"slug": ["oran", "onap", ...]}`

2. **Matrix Jobs** - Each job independently fetches its configuration:
   - Receives: `slug="aether"` (from ACTIVE_PROJECTS)
   - Reads `PROJECTS_JSON` secret directly
   - Extracts: `project`, `gerrit`, `github`, `jenkins`, `jenkins_user`, `jenkins_token`
   - Sets credentials in `GITHUB_ENV` (not in outputs)

**Benefits:**

- ✅ Matrix built from variable, not secret (no trace)
- ✅ Secrets never touch job outputs
- ✅ Each job is self-contained and secure
- ✅ Easy to add/remove projects by updating ACTIVE_PROJECTS

**Maintaining ACTIVE_PROJECTS:**

When you add or remove a project:

1. Update `testing/projects.json`
2. Extract the slugs:

   ```bash
   cat testing/projects.json | jq -c '[.[] | .slug]'
   ```

3. Update the ACTIVE_PROJECTS variable at:
   `https://github.com/modeseven-lfit/project-reporting-tool/settings/variables/actions`

#### Why Did the Workflow Fail?

If you encountered this error in the GitHub Actions workflow:

```text
❌ Verify Configuration failed
PROJECTS_JSON contains invalid JSON
```

**Root Cause:** The `PROJECTS_JSON` secret in GitHub contained invalid JSON or didn't match the expected schema.

**Solution:**

1. Copy the exact content from `testing/projects.json` (which now passes validation)
2. Go to: `https://github.com/modeseven-lfit/project-reporting-tool/settings/secrets/actions`
3. Update the `PROJECTS_JSON` secret with the copied content
4. Ensure no extra whitespace, newlines, or formatting changes when pasting
5. Re-run the workflow

**Verification:** The local validation script performs the exact same checks as the GitHub workflow:

```bash
./scripts/check-projects-json.sh testing/projects.json
```

If this passes locally, the workflow will pass in GitHub (assuming the secret matches).
