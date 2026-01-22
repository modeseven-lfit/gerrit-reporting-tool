<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Test Fixtures

This directory contains test fixtures for the Repository Reporting System tests.

## Structure

```text
fixtures/
├── README.md                          # This file
├── minimal_production_data.json       # Real production data (minimal subset)
├── synthetic_repos/                   # Synthetic git repositories for testing
│   ├── active_project/                # Repository with recent commits
│   ├── inactive_project/              # Repository with old commits
│   ├── no_commits/                    # Empty repository
│   └── multi_contributor/             # Repository with multiple authors
├── configs/                           # Test configuration files
│   ├── minimal.yaml                   # Minimal valid configuration
│   ├── full_featured.yaml             # Complete configuration with all features
│   └── invalid.yaml                   # Invalid configuration for error testing
├── expected_outputs/                  # Expected JSON schema snapshots
│   ├── baseline_schema.json           # Baseline JSON schema digest
│   └── snapshots/                     # Output snapshots for regression tests
└── api_responses/                     # Mock API responses
    ├── github/                        # GitHub API mock responses
    ├── gerrit/                        # Gerrit API mock responses
    └── jenkins/                       # Jenkins API mock responses
```

## Production Data Fixture

### minimal_production_data.json

**Real production data** extracted from OpenDaylight project report (January 2026).

This is a **minimal subset** (724 KB, 96.6% reduction from 20.7 MB original) containing:

- **2 repositories** from summaries (controller, netconf)
- **2 repositories** with full data (integration/distribution, transportpce/models)
- **2 organizations** (pantheon.tech, linuxfoundation.org)
- **2 contributors** by commits (Robert Varga, Anil Belur)
- **Real Jenkins jobs, GitHub workflows, and feature detection data**

**Source:** `examples/Opendaylight/report_raw.json` (full production run)

**Purpose:**

- Validate templates with real data structures
- Test context builders with actual production schemas
- Verify rendering pipeline with real-world edge cases
- Used automatically by `scripts/audit_templates.py` for runtime verification

**Data Characteristics:**

- Real repository names (e.g., "integration/distribution")
- Real contributor emails and domains
- Actual Jenkins job names and statuses
- Real feature detection results
- Time-windowed metrics (last_30, last_90, last_365, last_3_years)
- Nested structures matching production schema

**Regenerating:**

```bash
# Extract fresh minimal dataset from new production run
python scripts/extract_minimal_test_data.py \
  --input examples/Opendaylight/report_raw.json \
  --output tests/fixtures/minimal_production_data.json \
  --repos 2 --orgs 2 --contributors 2
```

**Usage in Tests:**

```python
import json
from pathlib import Path

def load_production_fixture():
    fixture_path = Path(__file__).parent / "fixtures" / "minimal_production_data.json"
    with open(fixture_path) as f:
        return json.load(f)

# Use in tests
def test_with_real_data():
    data = load_production_fixture()
    assert data['summaries']['top_organizations'][0]['domain'] == 'pantheon.tech'
```

**Used By:**

- `scripts/audit_templates.py` - Template field verification with real data
- Integration tests - End-to-end rendering validation
- Context builder tests - Verify handling of production data structures

## Synthetic Repositories

Each synthetic repository under `synthetic_repos/` is a minimal git repository
designed to test specific scenarios:

### active_project

- Recent commits (within last 30 days)
- Multiple contributors
- Has `.github/workflows/` directory
- Activity status: "current"

### inactive_project

- Last commit >3 years ago
- Single contributor
- No CI/CD workflows
- Activity status: "inactive"

### no_commits

- Initialized repository with no commits
- Tests edge case handling
- Activity status: "no_commits"

### multi_contributor

- 5+ unique authors
- Commits spanning multiple time windows
- Mixed organizational domains
- Tests author/org aggregation

## Configuration Files

### minimal.yaml

Bare minimum configuration required to run the system:

- Project name
- Time windows (defaults)
- Basic feature toggles

### full_featured.yaml

Complete configuration showcasing all available options:

- All extensions enabled (GitHub API, Gerrit, Jenkins)
- Custom time windows
- Advanced rendering options
- Performance tuning settings

### invalid.yaml

Intentionally malformed configuration for testing validation:

- Missing required fields
- Invalid data types
- Out-of-range values

## Expected Outputs

### baseline_schema.json

SHA256 digest of the canonical JSON schema structure.
Generated from a known-good run and frozen for regression testing.

Format:

```json
{
  "schema_version": "1.0.0",
  "digest": "sha256:abcd1234...",
  "generated_at": "2025-01-15T12:00:00Z",
  "stable_fields": [
    "schema_version",
    "generated_at",
    "project",
    "repositories",
    "authors",
    "organizations",
    "summaries"
  ]
}
```text

### snapshots/

Full JSON output snapshots for specific test scenarios.
Used for byte-level comparison in regression tests.

## API Response Mocks

Mock API responses allow testing without live API dependencies.

### Structure

Each API mock directory contains:

- `success/` - Valid successful responses
- `errors/` - Error responses (404, 500, rate limit, etc.)
- `edge_cases/` - Unusual but valid responses

### Usage

Tests can load these fixtures using:

```python
import json
from pathlib import Path

def load_fixture(api_type, scenario, filename):
    fixture_path = Path(__file__).parent / "fixtures" / "api_responses" / api_type / scenario / filename
    with open(fixture_path) as f:
        return json.load(f)
```

## Creating New Fixtures

### Adding a Synthetic Repository

1. Create directory: `mkdir -p synthetic_repos/my_test_repo`
2. Initialize git: `cd synthetic_repos/my_test_repo && git init`
3. Add commits with controlled metadata:

   ```bash
   GIT_AUTHOR_DATE="2024-01-15 12:00:00" \
   GIT_COMMITTER_DATE="2024-01-15 12:00:00" \
   git commit --allow-empty -m "Test commit" \
     --author="Test User <test@example.org>"
   ```

4. Document the purpose in this README

### Adding Configuration Fixture

1. Create YAML file in `configs/`
2. Ensure it follows the schema documented in main config
3. Add description to this README

### Updating Schema Digest

After intentional schema changes:

```bash
python generate_reports.py \
  --config-dir tests/fixtures/configs \
  --repos-path tests/fixtures/synthetic_repos \
  --output-dir tests/fixtures/expected_outputs/snapshots \
  --project baseline

# Generate new digest
python tests/regression/update_baseline_digest.py
```text

## Test Data Principles

1. **Deterministic**: All timestamps, authors, and content should be fixed
2. **Minimal**: Only include data necessary to test specific behavior
3. **Isolated**: Each fixture should be independent
4. **Documented**: Clear purpose and expected behavior
5. **Versioned**: Fixtures evolve with the schema version

## Maintenance

- Review fixtures quarterly for relevance
- Update snapshots when schema intentionally changes
- Archive obsolete fixtures to `fixtures/archived/`
- Keep fixture generation scripts in `fixtures/scripts/`

## See Also

- `tests/regression/test_baseline_json_schema.py` - Schema validation tests
- `tests/unit/` - Unit tests using these fixtures
- `REFACTOR_PLAN.md` - Overall refactoring strategy
