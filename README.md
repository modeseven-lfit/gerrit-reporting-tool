<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# 📊 Linux Foundation Project Reporting System

> Comprehensive multi-repository analysis tool for Linux Foundation projects

Generate detailed reports on Gerrit projects, contributor activity, Jenkins
jobs, GitHub CI/CD workflows, and development practices across repositories.

---

## 🗒️ Published Reports

<https://modeseven-lfit.github.io/gerrit-reporting-tool/>

## ⚡ Quick Start

```bash
# Install
pip install .

# Generate your first report
gerrit-reporting-tool generate \
  --project my-project \
  --repos-path ./repos
```

---

## 🚀 Key Features

- **📈 Git Analytics** - Commit activity, lines of code, contributor metrics across configurable time windows
- **📋 INFO.yaml Reporting** - Project metadata, committer activity, and lifecycle state tracking from info-master
- **🔍 Feature Detection** - Automatic detection of CI/CD, documentation, dependency management, security tools
- **👥 Contributor Intelligence** - Author and organization analysis with domain mapping
- **🌐 API Integration** - GitHub, Gerrit, and Jenkins API support
- **🎯 CI-Management Integration** - Authoritative Jenkins job allocation using JJB definitions (99%+ accuracy)
- **📊 Interactive Reports** - JSON (data), Markdown (readable), HTML (interactive), ZIP (bundled)
- **⚡ High Performance** - Parallel processing with caching support

---

## 📚 Documentation

### 🎯 Getting Started

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - Complete installation and setup walkthrough
- **[Commands Reference](docs/COMMANDS.md)** - Full command-line reference with quick reference
- **[FAQ](docs/FAQ.md)** - Frequently asked questions
- **[Usage Examples](docs/USAGE_EXAMPLES.md)** - Real-world scenarios and patterns

### ⚙️ Setup & Configuration

- **[Configuration Guide](docs/CONFIGURATION.md)** - All configuration options (GitHub API, INFO.yaml, performance)
- **[Configuration Merging](docs/CONFIGURATION_MERGING.md)** - How project configs inherit and override defaults
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Production deployment and operations
- **[CI/CD Integration](docs/CI_CD_INTEGRATION.md)** - GitHub Actions, GitLab CI, and automation

### 🔧 Advanced Usage

- **[Performance Guide](docs/PERFORMANCE.md)** - Optimization, caching, and scaling
- **[Feature Discovery](docs/FEATURE_DISCOVERY_GUIDE.md)** - Understanding automatic feature detection
- **[INFO.yaml Reporting](docs/INFO_YAML_REPORTING.md)** - Project metadata and committer activity tracking
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Problem solving and debugging

### 👨‍💻 Development

- **[Developer Guide](docs/DEVELOPER_GUIDE.md)** - Architecture, API reference, and contributing
- **[Testing Guide](docs/TESTING.md)** - Test suite documentation

---

## 💻 Installation

### Using UV (Recommended)

```bash
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync

# Run the tool
uv run gerrit-reporting-tool generate --project my-project --repos-path ./repos
```

### Using pip

```bash
# Install from source
pip install .

# Run the tool
# Note: repos-path should match the directory created by gerrit-clone-action
# which defaults to the Gerrit server hostname (e.g., ./gerrit.o-ran-sc.org)
gerrit-reporting-tool generate --project O-RAN-SC --repos-path ./gerrit.o-ran-sc.org
```

**→ [Detailed Setup Instructions](SETUP.md)**

---

## 🎯 Common Use Cases

| Use Case                    | Command                                                                                                    |
| --------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Basic report (O-RAN-SC)** | `gerrit-reporting-tool generate --project O-RAN-SC --repos-path ./gerrit.o-ran-sc.org`                     |
| **Basic report (ONAP)**     | `gerrit-reporting-tool generate --project ONAP --repos-path ./gerrit.onap.org`                             |
| **With caching**            | `gerrit-reporting-tool generate --project O-RAN-SC --repos-path ./gerrit.o-ran-sc.org --cache --workers 8` |
| **Check config**            | `gerrit-reporting-tool generate --project O-RAN-SC --repos-path ./gerrit.o-ran-sc.org --dry-run`           |
| **Get help**                | `gerrit-reporting-tool --help`                                                                             |

> **Note:** The `--repos-path` should point to the directory created by `gerrit-clone-action`, which uses the Gerrit server hostname as the directory name (e.g., `./gerrit.o-ran-sc.org` for O-RAN-SC, `./gerrit.onap.org` for ONAP).

---

## 📊 Output Formats

```text
reports/
  <PROJECT>/
    ├── report_raw.json              # Complete dataset (canonical)
    ├── report.md                    # Markdown report (readable)
    ├── report.html                  # Interactive HTML (sortable tables)
    ├── config_resolved.json         # Applied configuration
    └── <PROJECT>_report_bundle.zip  # Complete bundle
```

---

## 🔌 CI/CD Integration

### GitHub Actions

```yaml
- name: Generate Report
  run: |
    uv run gerrit-reporting-tool generate \
      --project "${{ matrix.project }}" \
      --repos-path "./${{ matrix.server }}" \
      --cache \
      --quiet
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 🔧 Requirements

- **Python**: 3.10+ (supports 3.10, 3.11, 3.12, 3.13)
- **Dependencies**: PyYAML, httpx, Jinja2, typer, rich
- **Optional**: GitHub token for API features (required for workflow status colors)

### GitHub Token Requirements

For full workflow status reporting (colored status indicators), you need a GitHub Personal Access Token (Classic) with these permissions:

**Required Scopes:**

- ☑ `repo` - Full repository access (or `public_repo` for public repositories)
- ☑ `actions:read` - Read GitHub Actions workflow runs and status

**Note:** Fine-grained tokens are not supported as they cannot span organizations.

**Setup:**

```bash
# Set environment variable
export GITHUB_TOKEN=ghp_your_token_here
# OR for CI/production:
export CLASSIC_READ_ONLY_PAT_TOKEN=ghp_your_token_here

# Then run the tool
gerrit-reporting-tool generate --project my-project --repos-path ./repos
```

**Create token:** <https://github.com/settings/tokens>

**Without a token:** The tool detects workflows but shows them as grey (unknown status) instead of colored status indicators.

**See also:** [Configuration Guide](docs/CONFIGURATION.md#github-api-integration) for detailed token setup

---

## 📖 Key Documentation Files

| Topic               | Document                                               |
| ------------------- | ------------------------------------------------------ |
| **Getting Started** | [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)     |
| **Commands**        | [docs/COMMANDS.md](docs/COMMANDS.md)                   |
| **FAQ**             | [docs/FAQ.md](docs/FAQ.md)                             |
| **Configuration**   | [docs/CONFIGURATION.md](docs/CONFIGURATION.md)         |
| **Usage Examples**  | [docs/USAGE_EXAMPLES.md](docs/USAGE_EXAMPLES.md)       |
| **Performance**     | [docs/PERFORMANCE.md](docs/PERFORMANCE.md)             |
| **Troubleshooting** | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)     |
| **CI/CD Setup**     | [docs/CI_CD_INTEGRATION.md](docs/CI_CD_INTEGRATION.md) |
| **Developer Guide** | [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)     |

---

## 💡 Quick Tips

- 🎯 **First time?** Start with [Getting Started Guide](docs/GETTING_STARTED.md)
- ⚡ **Slow?** Add `--cache --workers 8` for parallel processing
- 🐛 **Issues?** Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- ❓ **Questions?** See [FAQ](docs/FAQ.md)
- 📖 **Need help?** Run `gerrit-reporting-tool --help`

---

## 🤝 Support

- **Documentation**: [Complete Index](docs/INDEX.md)
- **Issues**: [GitHub Issues](https://github.com/modeseven-lfit/gerrit-reporting-tool/issues)

---

## 📜 License

Apache-2.0 License - Copyright 2025 The Linux Foundation

---
