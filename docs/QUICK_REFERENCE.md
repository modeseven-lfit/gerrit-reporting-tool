<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Quick Reference Guide - GitHub Pages Reporting System

Fast reference for common tasks and operations.

---

## 🚀 Common Tasks

### View Production Reports

```text
https://<owner>.github.io/<repo>/production/
```text

### View Preview Report

```text
https://<owner>.github.io/<repo>/pr-preview/<pr-number>/
```text

### Manually Trigger Production Report

1. Go to **Actions** → **📊 Production Reports**
2. Click **Run workflow**
3. Select branch → **Run workflow**

---

## 🔑 Required Secrets

<!-- markdownlint-disable MD060 -->

| Secret                          | Required    | Purpose                   |
| ------------------------------- | ----------- | ------------------------- |
| `CLASSIC_READ_ONLY_PAT_TOKEN`   | ✅ Yes      | GitHub API access         |
| `LF_GERRIT_INFO_MASTER_SSH_KEY` | ⚠️ Optional | SSH clone for info-master |

<!-- markdownlint-enable MD060 -->

---

## 📋 Required Variables

| Variable        | Format     | Example   |
| --------------- | ---------- | --------- |
| `PROJECTS_JSON` | JSON array | See below |

**PROJECTS_JSON Format:**

```json
[
  {
    "project": "Project Name",
    "slug": "project-name",
    "gerrit": "gerrit.example.org",
    "jenkins": "jenkins.example.org",
    "github": "github-org"
  }
]
```

**Required:** `project`, `slug`, `gerrit`
**Optional:** `jenkins`, `github`, `jjb_attribution`

```text

---

## 📊 Workflows

### Production Reports (`reporting-production.yaml`)

- **Schedule:** Monday 7:00 AM UTC
- **Trigger:** Manual via workflow_dispatch
- **Output:** `/production/<project-slug>/`
- **Artifacts:** 90-day retention
- **Projects:** All configured projects

### Preview Report (`reporting-pr-preview.yaml`)

- **Schedule:** On PR to reporting code
- **Trigger:** Automatic on code changes
- **Output:** `/pr-preview/<pr-number>/`
- **Artifacts:** 30-day retention
- **Projects:** First 2 projects only

---

## 🗂️ GitHub Pages Structure

```text
/                              # Root landing page
├── production/                # Production reports
│   ├── index.html            # Report listing
│   └── <project-slug>/
│       ├── report.html       # Interactive report
│       ├── report_raw.json   # Raw data
│       ├── report.md         # Markdown report
│       └── metadata.json     # Generation metadata
└── pr-preview/               # Preview reports
    └── <pr-number>/          # PR-specific reports
        ├── index.html
        └── <project-slug>/
            └── ...
```text

---

## 🔧 Setup Quick Steps

### 1. Enable GitHub Pages

```bash
# Settings → Pages
# Source: gh-pages branch, / (root)
```text

### 2. Create gh-pages Branch

```bash
git checkout --orphan gh-pages
git rm -rf .
mkdir -p production pr-preview
echo "Coming soon" > index.html
git add .
git commit -m "chore: init gh-pages"
git push origin gh-pages
git checkout main
```text

### 3. Set Permissions

```bash
# Settings → Actions → General
# ✅ Read and write permissions
# ✅ Allow Actions to create PRs
```text

---

## 📦 Artifacts

### Production Workflow

| Artifact                   | Contents         | Retention |
| -------------------------- | ---------------- | --------- |
| `raw-data-<project>`       | JSON data files  | 90 days   |
| `reports-<project>`        | All report files | 90 days   |
| `clone-manifest-<project>` | Clone tracking   | 90 days   |
| `clone-log-<project>`      | Clone logs       | 90 days   |

### Preview Report Workflow

| Artifact                              | Contents  | Retention |
| ------------------------------------- | --------- | --------- |
| `pr-preview-raw-data-<project>`       | JSON data | 30 days   |
| `pr-preview-reports-<project>`        | Reports   | 30 days   |
| `pr-preview-clone-manifest-<project>` | Manifests | 30 days   |

---

## 🐛 Troubleshooting

### Reports Not Showing

```bash
# Check gh-pages branch
git fetch origin gh-pages
git checkout gh-pages
ls -la production/

# Check GitHub Pages status
# Settings → Pages → Check deployment status
```text

### Workflow Failing

```bash
# Check workflow logs
# Actions → Select failed run → Review logs

# Verify secrets exist
# Settings → Secrets and variables → Actions

# Validate PROJECTS_JSON
echo '${{ vars.PROJECTS_JSON }}' | jq .
```text

### Preview Report Not Working

```bash
# Verify PR modifies correct paths:
# - src/**/*.py
# - .github/workflows/reporting-*.yaml
# - .github/scripts/*.sh

# Check workflow permissions
# Settings → Actions → General → Read and write
```text

---

## 📥 Download Historical Data

```bash
# Set token
export GITHUB_TOKEN=ghp_...

# Download last 90 days
.github/scripts/download-artifacts.sh \
  reporting-production.yaml \
  ./historical-data \
  90
```text

---

## 🔄 Adding New Project

1. Edit `PROJECTS_JSON` variable:

```json
{
  "project": "New Project",
  "gerrit": "gerrit.newproject.org",
  "jenkins": "jenkins.newproject.org",
  "github": "newproject-org"
}
```text

2. Save variable

3. Next workflow run will include it

---

## 📞 Quick Links

| Resource        | Link                                                      |
| --------------- | --------------------------------------------------------- |
| **Setup Guide** | [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)            |
| **Migration**   | [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)          |
| **Scripts**     | [.github/scripts/README.md](../.github/scripts/README.md) |
| **Main Docs**   | [README.md](../README.md)                                 |

---

## 🆘 Emergency Contacts

- **Issues:** GitHub Issues tab
- **Documentation:** `/docs` directory
- **Workflow Logs:** Actions tab

---

## 💡 Tips

- ✅ Production runs Monday 7am UTC
- ✅ Preview reports use only 2 projects
- ✅ Artifacts retained 90 days (production), 30 days (preview)
- ✅ Use download script for meta-reporting
- ✅ Check gh-pages branch for published content

---

**Version:** 2.0
**Updated:** 2025-01-XX
