<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# GitHub Native Project Support - Implementation Plan

> Implementation plan for adding GitHub-only project support to the project-reporting-tool

**Status:** ✅ Implemented
**Created:** 2025-01-XX
**Completed:** 2025-01-XX
**Author:** Implementation Team
**Schema Version:** 1.5.0

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Background](#background)
3. [Requirements](#requirements)
4. [Current Architecture Analysis](#current-architecture-analysis)
5. [Proposed Changes](#proposed-changes)
6. [Implementation Phases](#implementation-phases)
7. [Testing Strategy](#testing-strategy)
8. [Migration Path](#migration-path)
9. [Risks and Mitigations](#risks-and-mitigations)
10. [Success Criteria](#success-criteria)

---

## Executive Summary

**✅ IMPLEMENTATION COMPLETE**

The project-reporting-tool now supports both Gerrit-based projects and **GitHub-native projects** that have no Gerrit backend. This implementation adds the ability to analyze and report on projects hosted entirely on GitHub while maintaining full backward compatibility with existing Gerrit-based projects.

**Key Changes Implemented:**

- ✅ Support two project configuration templates: Gerrit-based and GitHub-native
- ✅ Preserved existing data structures and JSON schema (no breaking changes)
- ✅ Updated terminology in templates from "Gerrit Project" → "Repository" (dynamic)
- ✅ Maintained full backward compatibility with existing Gerrit-based projects
- ✅ Added Aether project as first GitHub-native implementation
- ✅ Bumped schema version from 1.4.0 to 1.5.0

**Impact:** Minimal code changes achieved - primarily template updates and configuration handling (~8 files modified).

---

## Background

### Current State

All projects currently supported use this configuration pattern:

```json
{
  "project": "ONAP",
  "slug": "onap",
  "gerrit": "gerrit.onap.org",
  "jenkins": "jenkins.onap.org",
  "github": "onap"  // Optional: for GitHub mirror
}
```

**Data Flow:**

1. Repositories are cloned from Gerrit using SSH
2. Git metrics are collected from local clones
3. Gerrit API provides additional project metadata
4. GitHub API optionally used for workflow status
5. Reports reference "Gerrit Projects" throughout

### Target State

Support GitHub-native projects with this configuration:

```json
{
  "project": "Aether",
  "slug": "aether",
  "github": "opennetworkinglab"  // GitHub org name, NO gerrit key
}
```

**New Data Flow:**

1. Repositories are cloned from GitHub (HTTPS or SSH)
2. Git metrics collected identically (same code path)
3. **No Gerrit API calls** (skip gracefully)
4. GitHub API used for repository discovery and workflow status
5. Reports use generic terminology: "Repository" instead of "Gerrit Project"

---

## Requirements

### Functional Requirements

1. **FR-1:** Support project configurations with `github` key but no `gerrit` key
2. **FR-2:** Clone repositories from GitHub organizations when Gerrit is not configured
3. **FR-3:** Preserve all existing Git metrics collection (commits, LOC, contributors)
4. **FR-4:** Maintain Jenkins job attribution for projects with ci-management repos
5. **FR-5:** Display appropriate terminology in reports based on project type
6. **FR-6:** Support INFO.yaml reporting where applicable
7. **FR-7:** Maintain backward compatibility with all existing Gerrit-based projects

### Non-Functional Requirements

1. **NFR-1:** No breaking changes to existing JSON data schema
2. **NFR-2:** Minimal code changes (prefer configuration over code)
3. **NFR-3:** Template-driven terminology changes
4. **NFR-4:** Performance parity with Gerrit-based projects
5. **NFR-5:** Clear documentation for both project types

---

## Current Architecture Analysis

### Data Collection Flow

```text
PROJECTS_JSON → Configuration → Clone Action → Git Metrics → Rendering → Reports
```

### Key Components

#### 1. Configuration System

**Location:** `src/project_reporting_tool/config.py`

**Current Behavior:**

- Auto-derives `github_org` from `gerrit.host` (e.g., `gerrit.onap.org` → `onap`)
- Expects `gerrit.host` to always be present
- Uses Gerrit host for INFO.yaml filtering

**Required Changes:**

- Make `gerrit.host` optional
- Support explicit `github` org from PROJECTS_JSON
- Provide default values for Gerrit-specific fields when absent

#### 2. Git Data Collector

**Location:** `src/project_reporting_tool/collectors/git.py`

**Current Behavior:**

- Builds metrics with Gerrit-centric field names:
  - `gerrit_project`
  - `gerrit_host`
  - `gerrit_url`
  - `gerrit_path_prefix`

**Required Changes:**

- **NONE** - Keep existing field names for backward compatibility
- These become "semantic" fields that represent the source system
- For GitHub-native projects, populate with GitHub equivalents:
  - `gerrit_project` → repository name (e.g., `aether/sdcore`)
  - `gerrit_host` → GitHub organization (e.g., `opennetworkinglab`)
  - `gerrit_url` → GitHub repository URL
  - `gerrit_path_prefix` → empty string or `/`

#### 3. Repository Metrics Domain Model

**Location:** `src/domain/repository_metrics.py`

**Current Fields:**

```python
@dataclass
class RepositoryMetrics:
    gerrit_project: str
    gerrit_host: str
    gerrit_url: str
    local_path: str
    # ... rest of fields
```

**Required Changes:**

- **NONE** - Keep field names unchanged
- Update docstrings to clarify these are "source system" identifiers
- Works for both Gerrit and GitHub sources

#### 4. Rendering Templates

**Locations:**

- `src/templates/markdown/sections/summary.md.j2`
- `src/templates/markdown/sections/repositories.md.j2`
- `src/templates/html/sections/summary.html.j2`
- `src/templates/html/sections/repositories.html.j2`

**Current Terminology:**

- "Total Gerrit Projects"
- "Current Gerrit Projects"
- "Gerrit Project" (column header)

**Required Changes:**

- Make terminology configurable based on project type
- Add context variable: `project_type` ("gerrit" or "github")
- Update headers and labels conditionally

#### 5. Context Builder

**Location:** `src/rendering/context.py`

**Current Behavior:**

- Builds `gerrit_project` references in repository context
- Constructs Gerrit admin URLs

**Required Changes:**

- Detect project type from configuration
- Build appropriate URLs based on type:
  - Gerrit: `https://gerrit.onap.org/r/admin/repos/oom,general`
  - GitHub: `https://github.com/opennetworkinglab/aether`

---

## Proposed Changes

### 1. Configuration Schema Enhancement

**File:** `src/config/schema.json` (if exists) and documentation

**Add project type detection:**

```yaml
# Project type is auto-detected from configuration:
# - If "gerrit" key exists: type = "gerrit"
# - If "github" key exists but no "gerrit": type = "github"
# - If both exist: type = "gerrit" (legacy behavior)

project:
  type: auto  # auto-detected, can override with "gerrit" or "github"
  name: "Project Name"

gerrit:  # Optional for GitHub-native projects
  host: ""
  enabled: false  # Auto-set to false if host is empty

github:  # Required for GitHub-native projects
  org: ""  # From PROJECTS_JSON or auto-derived
```

### 2. Template Terminology System

**Approach:** Context-driven template variables

**New Context Variables:**

```python
# In rendering/context.py -> _build_project_context()
context = {
    "project_type": "github",  # or "gerrit"
    "terminology": {
        "repository": "Repository",  # or "Gerrit Project"
        "repositories": "Repositories",  # or "Gerrit Projects"
        "source_system": "GitHub",  # or "Gerrit"
    }
}
```

**Template Usage:**

```jinja2
{# Before #}
## 📊 Gerrit Projects

{# After #}
## 📊 {{ terminology.repositories }}

{# Before #}
| Gerrit Project | Commits | LOC |

{# After #}
| {{ terminology.repository }} | Commits | LOC |
```

### 3. URL Construction Logic

**File:** `src/rendering/context.py` → `_build_repositories_context()`

**Current:**

```python
gerrit_admin_url = f"https://{gerrit_host}{gerrit_path_prefix}/admin/repos/{gerrit_project_name},general"
```

**Proposed:**

```python
def _build_repository_url(self, repo_data: dict, project_type: str) -> str:
    """Build URL to repository based on project type."""
    if project_type == "gerrit":
        gerrit_host = repo_data.get("gerrit_host", "")
        gerrit_path_prefix = repo_data.get("gerrit_path_prefix", "")
        gerrit_project = repo_data.get("gerrit_project", "")
        return f"https://{gerrit_host}{gerrit_path_prefix}/admin/repos/{gerrit_project},general"
    elif project_type == "github":
        github_org = repo_data.get("gerrit_host", "")  # Stored in gerrit_host field
        repo_name = repo_data.get("gerrit_project", "")  # Stored in gerrit_project field
        return f"https://github.com/{github_org}/{repo_name}"
    else:
        return ""
```

### 4. Testing Configuration

**File:** `testing/projects.json`

**Add Aether project:**

```json
[
  {
    "project": "O-RAN-SC",
    "slug": "oran",
    "gerrit": "gerrit.o-ran-sc.org",
    "jenkins": "jenkins.o-ran-sc.org"
  },
  {
    "project": "Aether",
    "slug": "aether",
    "github": "opennetworkinglab"
  }
]
```

### 5. Local Testing Script

**File:** `testing/local-testing.sh`

**Add GitHub cloning support:**

```bash
# Detect project type from projects.json
if [ -n "$gerrit_server" ]; then
    # Existing Gerrit clone logic
    clone_gerrit_repos "$gerrit_server" "$clone_dir"
elif [ -n "$github_org" ]; then
    # New GitHub clone logic
    clone_github_repos "$github_org" "$clone_dir"
fi

clone_github_repos() {
    local org="$1"
    local target_dir="$2"

    log_info "Cloning GitHub repositories for org: $org"

    # List repositories using GitHub API
    gh repo list "$org" --limit 1000 --json name --jq '.[].name' | while read -r repo; do
        log_info "  Cloning $org/$repo"
        git clone "https://github.com/$org/$repo.git" "$target_dir/$repo"
    done
}
```

---

## Implementation Phases

### Phase 1: Configuration and Detection (Week 1)

**Tasks:**

1. Update configuration loader to make `gerrit.host` optional
2. Add project type detection logic
3. Add terminology context builder
4. Update documentation

**Files Modified:**

- `src/project_reporting_tool/config.py`
- `src/rendering/context.py`
- `docs/CONFIGURATION.md`

**Validation:**

- Configuration loads correctly for both types
- Project type correctly detected
- No breaking changes to existing configs

### Phase 2: Template Updates (Week 1-2)

**Tasks:**

1. Update summary templates (Markdown + HTML)
2. Update repositories templates (Markdown + HTML)
3. Update other templates as needed
4. Run template audit script

**Files Modified:**

- `src/templates/markdown/sections/summary.md.j2`
- `src/templates/markdown/sections/repositories.md.j2`
- `src/templates/html/sections/summary.html.j2`
- `src/templates/html/sections/repositories.html.j2`

**Validation:**

- `python scripts/audit_templates.py` passes
- Rendered reports show correct terminology
- No template syntax errors

### Phase 3: URL Construction (Week 2)

**Tasks:**

1. Add URL builder function for both project types
2. Update context builder to use new URL logic
3. Test URL generation

**Files Modified:**

- `src/rendering/context.py`

**Validation:**

- Gerrit URLs unchanged for existing projects
- GitHub URLs correct for new projects
- URLs clickable in HTML reports

### Phase 4: Testing Infrastructure (Week 2)

**Tasks:**

1. Update `testing/projects.json` with Aether
2. Enhance `testing/local-testing.sh` with GitHub support
3. Create test fixture for GitHub-native project
4. Add integration tests

**Files Modified:**

- `testing/projects.json`
- `testing/local-testing.sh`
- `tests/integration/test_github_native.py` (new)

**Validation:**

- Local testing script works for Aether
- Integration tests pass
- Can generate full report for GitHub project

### Phase 5: Documentation and Polish (Week 3)

**Tasks:**

1. Update README with GitHub-native examples
2. Update CONFIGURATION.md with both templates
3. Add GITHUB_NATIVE_GUIDE.md
4. Update FAQ
5. Update PROJECTS_JSON documentation

**Files Modified:**

- `README.md`
- `docs/CONFIGURATION.md`
- `docs/GITHUB_NATIVE_GUIDE.md` (new)
- `docs/FAQ.md`
- `SETUP.md`

**Validation:**

- Documentation complete and accurate
- Examples work as documented
- Clear guidance for both project types

---

## Testing Strategy

### Unit Tests

**New Test Cases:**

1. `test_config_github_native.py`
   - Test project type detection
   - Test GitHub-native configuration loading
   - Test Gerrit configuration still works

2. `test_context_terminology.py`
   - Test terminology generation
   - Test URL building for both types
   - Test context variables

3. `test_templates_terminology.py`
   - Test template rendering with terminology
   - Test both Gerrit and GitHub reports
   - Test no regression for existing projects

### Integration Tests

**New Test Cases:**

1. `test_github_native_integration.py`
   - End-to-end test with mock GitHub org
   - Verify JSON schema compliance
   - Verify all sections render correctly

2. `test_mixed_projects.py`
   - Test handling both project types in same run
   - Verify no cross-contamination
   - Verify terminology switches correctly

### Manual Testing

**Test Plan:**

1. Generate report for Aether project locally
2. Verify all metrics collected correctly
3. Verify terminology appropriate throughout
4. Compare side-by-side with ONAP report
5. Check HTML interactivity works
6. Verify JSON schema identical structure

---

## Migration Path

### For Production Deployment

**Step 1: Deploy to Test Repository**

```bash
# In test-project-reporting-tool
git checkout -b github-native-support
# ... implement changes ...
./testing/local-testing.sh --project aether
# Verify reports/Aether/* looks correct
```

**Step 2: Add Aether to Test Workflow**

```yaml
# In .github/workflows/reporting-previews.yaml
# Add Aether to matrix (after code merge)
```

**Step 3: Monitor Preview Reports**

- Check generated reports in GitHub Actions
- Verify no errors in workflow logs
- Compare metrics with production Gerrit projects

**Step 4: Port to Production Repository**

```bash
# In project-reporting-tool (production)
git checkout -b github-native-support
# Cherry-pick changes from test repo
# Update PROJECTS_JSON variable in production
```

**Step 5: Gradual Rollout**

1. Add Aether to production PROJECTS_JSON
2. Monitor first production run
3. Validate published reports on GitHub Pages
4. Announce availability to stakeholders

### Backward Compatibility Guarantee

**Commitment:**

- All existing Gerrit-based projects continue to work unchanged
- JSON data structure remains identical
- No API changes to existing collectors
- Template updates backward compatible

**Validation:**

- Run existing integration tests (must pass)
- Generate reports for ONAP, ODL (compare with baseline)
- Check JSON schema compliance
- Verify no new errors in logs

---

## Risks and Mitigations

### Risk 1: Data Structure Changes Break Consumers

**Impact:** High
**Probability:** Low

**Mitigation:**

- Keep all field names unchanged (`gerrit_project`, `gerrit_host`, etc.)
- Only change template display text
- Add new optional fields, never remove existing
- Run schema validation tests

### Risk 2: Template Changes Introduce Errors

**Impact:** Medium
**Probability:** Medium

**Mitigation:**

- Use template audit script before commit
- Add comprehensive template tests
- Manual review of all rendered reports
- Gradual rollout to preview first

### Risk 3: GitHub API Rate Limiting

**Impact:** Medium
**Probability:** Medium

**Mitigation:**

- GitHub API already used for existing projects
- Use authenticated requests (CLASSIC_READ_ONLY_PAT_TOKEN)
- Implement caching for repository lists
- Monitor rate limit headers

### Risk 4: INFO.yaml Reporting Incompatibility

**Impact:** Low
**Probability:** Medium

**Mitigation:**

- INFO.yaml reporting remains Gerrit-centric (by design)
- GitHub-native projects simply won't have INFO.yaml data
- This is expected and acceptable
- Document clearly in user guide

### Risk 5: Jenkins Job Attribution Complexity

**Impact:** Medium
**Probability:** Low

**Mitigation:**

- Aether likely has ci-management in Gerrit
- JJB attribution works via repository URL matching
- Can point to Gerrit ci-management even for GitHub projects
- Test with Aether's actual setup

---

## Success Criteria

### Must Have (P0)

- [ ] Aether project successfully added to testing/projects.json
- [ ] Local testing script generates complete Aether report
- [ ] All existing Gerrit projects still work (ONAP, ODL tested)
- [ ] Templates show "Repository" for Aether, "Gerrit Project" for others
- [ ] JSON schema validation passes for both project types
- [ ] No breaking changes to existing data structures
- [ ] Template audit script passes
- [ ] All unit tests pass
- [ ] All integration tests pass

### Should Have (P1)

- [ ] Documentation updated for both project types
- [ ] GitHub-native guide published
- [ ] FAQ updated with common questions
- [ ] Integration tests for mixed project scenarios
- [ ] Performance parity with Gerrit projects

### Nice to Have (P2)

- [ ] Automatic repository discovery via GitHub API
- [ ] GitHub-specific metrics (PRs, Issues)
- [ ] Enhanced workflow reporting for GitHub Actions
- [ ] Migration guide for Gerrit → GitHub projects

---

## Open Questions

### Q1: Should we rename `gerrit_project` field to `repository`?

**Answer:** No - breaking change, not worth the risk. Keep field names, change display only.

### Q2: How to handle projects with both Gerrit and GitHub?

**Answer:** Keep existing behavior - if `gerrit` key exists, treat as Gerrit project. GitHub is optional mirror.

### Q3: What about Gerrit metrics (change counts, review stats)?

**Answer:** Not collected currently, so no impact. If added later, make conditional on project type.

### Q4: Should terminology be configurable per-project?

**Answer:** No - auto-detect from project configuration. Simpler, less error-prone.

### Q5: How to test without access to full Aether repositories?

**Answer:** Use mock data, small subset, or create minimal test fixture. Real testing in preview workflow.

---

## Appendix A: Configuration Examples

### Gerrit-Based Project (Existing)

```yaml
project:
  name: "ONAP"
  slug: "onap"

gerrit:
  host: "gerrit.onap.org"
  enabled: true
  base_url: "/r"

jenkins:
  host: "jenkins.onap.org"

github:
  org: "onap"  # Optional mirror
```

### GitHub-Native Project (New)

```yaml
project:
  name: "Aether"
  slug: "aether"

gerrit:
  enabled: false  # Auto-set when host empty

github:
  org: "opennetworkinglab"

jenkins:
  # May still have Jenkins via ci-management
  enabled: false
```

---

## Appendix B: Template Terminology Mapping

| Context      | Gerrit Term                 | GitHub Term              |
| ------------ | --------------------------- | ------------------------ |
| Summary      | "Total Gerrit Projects"     | "Total Repositories"     |
| Summary      | "Current Gerrit Projects"   | "Current Repositories"   |
| Summary      | "Active Gerrit Projects"    | "Active Repositories"    |
| Summary      | "Inactive Gerrit Projects"  | "Inactive Repositories"  |
| Repositories | "Gerrit Projects" (heading) | "Repositories" (heading) |
| Repositories | "Gerrit Project" (column)   | "Repository" (column)    |

---

## Appendix C: File Change Summary

### Modified Files (Estimated)

1. `src/project_reporting_tool/config.py` - Make gerrit.host optional
2. `src/rendering/context.py` - Add terminology context, URL builder
3. `src/templates/markdown/sections/summary.md.j2` - Use terminology variables
4. `src/templates/markdown/sections/repositories.md.j2` - Use terminology variables
5. `src/templates/html/sections/summary.html.j2` - Use terminology variables
6. `src/templates/html/sections/repositories.html.j2` - Use terminology variables
7. `testing/projects.json` - Add Aether
8. `testing/local-testing.sh` - Add GitHub cloning support

### New Files

1. `docs/GITHUB_NATIVE_IMPLEMENTATION_PLAN.md` - This document
2. `docs/GITHUB_NATIVE_GUIDE.md` - User guide for GitHub projects
3. `tests/integration/test_github_native.py` - Integration tests

### Documentation Updates

1. `README.md` - Add GitHub-native examples
2. `docs/CONFIGURATION.md` - Document both templates
3. `docs/FAQ.md` - Add GitHub-specific Q&A
4. `SETUP.md` - Update PROJECTS_JSON examples

**Total Estimated Changes:** ~15 files

---

## Conclusion

This implementation plan provides a minimal-impact approach to adding GitHub-native project support to the project-reporting-tool. By preserving existing data structures and using template-driven terminology changes, we can support both Gerrit and GitHub projects with minimal code changes and zero breaking changes to existing functionality.

The phased approach allows for incremental validation and testing, reducing deployment risk. The Aether project will serve as the first GitHub-native implementation, validating the approach before broader adoption.

**Implementation Summary:**

1. ✅ Schema version bumped to 1.5.0
2. ✅ Configuration system enhanced for GitHub-native projects
3. ✅ Templates updated with dynamic terminology
4. ✅ URL construction supports both project types
5. ✅ Aether project added to testing configuration
6. ✅ Local testing script enhanced with GitHub cloning
7. ✅ Documentation completed

**Ready for Testing:**

```bash
cd testing
./local-testing.sh --project Aether
```

---

**Document Version:** 2.0
**Last Updated:** 2025-01-XX
**Status:** ✅ Implementation Complete
