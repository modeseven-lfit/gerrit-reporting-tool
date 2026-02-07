<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# CI/CD Jobs Table Format Fix

**Date:** January 12, 2026
**Status:** ✅ Fixed
**Issue:** Table structure mismatch between new and production systems

---

## Problem Description

The new templating system (`test-project-reporting-tool`) was rendering the CI/CD Jobs table with a completely different structure than the production system (`project-reporting-tool`).

### Production System Table Format

The production system groups workflows and Jenkins jobs **by Gerrit project**, showing all jobs for each project in a single row:

| Gerrit Project | GitHub Workflows                              | Workflow Count | Jenkins Jobs                                                                         | Job Count |
| -------------- | --------------------------------------------- | -------------- | ------------------------------------------------------------------------------------ | --------- |
| aai/aai-common | call-github2gerrit.yaml<br>github2gerrit.yaml | 2              | aai-aai-common-master-verify-java<br>aai-aai-common-master-merge-java<br>...(6 more) | 8         |

### New System Table Format (Before Fix)

The new system was creating **one row per individual job**:

| Job Name                                        | Repository                   | Status  |
| ----------------------------------------------- | ---------------------------- | ------- |
| dcaegen2-collectors-restconf-maven-merge-master | dcaegen2/collectors/restconf | failure |
| dcaegen2-collectors-restconf-maven-stage-master | dcaegen2/collectors/restconf | success |

---

## Solution

The fix was implemented **entirely in the rendering layer** without modifying the underlying JSON data structure. This ensures backward compatibility and data stability.

### Changes Made

#### 1. Updated `src/rendering/context.py`

Modified `_build_workflows_context()` method to group jobs by repository for rendering:

**Key changes:**

- Build `repos_with_cicd` list grouping jobs by Gerrit project
- Include both `jenkins_jobs` and `github_workflows` arrays per repository
- Maintain counts: `jenkins_job_count`, `github_workflow_count`
- Calculate totals: `total_jenkins_jobs`, `total_github_workflows`, `total_repositories`
- Preserve legacy flat `all` list for backward compatibility

**Data structure provided to templates:**

```python
{
    "repositories": [
        {
            "gerrit_project": "aai/aai-common",
            "jenkins_jobs": [...],
            "jenkins_job_count": 8,
            "github_workflows": [...],
            "github_workflow_count": 2,
        },
        ...
    ],
    "total_jenkins_jobs": 1559,
    "total_github_workflows": 84,
    "total_repositories": 131,
    "status_counts": {...},
    "has_workflows": true,
}
```

#### 2. Updated `src/templates/html/sections/workflows.html.j2`

Completely rewrote the template to match production format:

**Features:**

- 5-column table: Gerrit Project, GitHub Workflows, Workflow Count, Jenkins Jobs, Job Count
- Groups all workflows/jobs for a project in single row
- Multiple items separated by `<br>` tags
- Color-coded status indicators:
  - Workflows: `status-success`, `status-failure`, `status-in-progress`, `status-disabled`, `status-unknown`
  - Jenkins: `status-success`, `status-failure`, `status-warning`, `status-building`, `status-aborted`
- Hyperlinks to GitHub workflow pages and Jenkins job pages
- Sortable table with `cicd-jobs-table` class for CSS styling

#### 3. Updated `src/templates/markdown/sections/workflows.md.j2`

Updated markdown template to match production format:

**Features:**

- Markdown table with 5 columns
- Multiple workflows/jobs per cell separated by `<br>` (Markdown allows HTML in tables)
- Summary totals at bottom

---

## Verification

### Test Data

Created sample test data with:

- 2 repositories
- 5 Jenkins jobs total (3 for aai/aai-common, 2 for aai/babel)
- 2 GitHub workflows (both for aai/aai-common)

### HTML Output

```html
<table class="data-table cicd-jobs-table sortable no-pagination">
    <thead>
        <tr>
            <th scope="col" class="gerrit-project">Gerrit Project</th>
            <th scope="col" class="github-workflows">GitHub Workflows</th>
            <th scope="col" class="workflow-count">Workflow Count</th>
            <th scope="col" class="jenkins-jobs">Jenkins Jobs</th>
            <th scope="col" class="job-count">Job Count</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td class="gerrit-project">aai/aai-common</td>
            <td class="github-workflows">
                <a href="..." target="_blank">
                    <span class="status-failure workflow-status">call-github2gerrit.yaml</span>
                </a><br>
                <a href="..." target="_blank">
                    <span class="status-failure workflow-status">github2gerrit.yaml</span>
                </a>
            </td>
            <td class="workflow-count">2</td>
            <td class="jenkins-jobs">
                <a href="..." target="_blank">
                    <span class="status-success jenkins-status">aai-aai-common-master-merge-java</span>
                </a><br>
                ...
            </td>
            <td class="job-count">3</td>
        </tr>
        ...
    </tbody>
</table>
```

### Markdown Output

```markdown
## 🏁 Deployed CI/CD Jobs

**Total GitHub workflows:** 2

**Total Jenkins jobs:** 5

| Gerrit Project | GitHub Workflows                              | Workflow Count | Jenkins Jobs                                                                                               | Job Count |
| -------------- | --------------------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------- | --------- |
| aai/aai-common | call-github2gerrit.yaml<br>github2gerrit.yaml | 2              | aai-aai-common-master-merge-java<br>aai-aai-common-master-verify-java<br>aai-aai-common-maven-stage-master | 3         |
| aai/babel      |                                               | 0              | aai-babel-maven-merge-master<br>aai-babel-maven-verify-master                                              | 2         |

**Total:** 2 repositories with CI/CD jobs
```

---

## Status Indicators

### GitHub Workflows

| Status      | CSS Class            | Trigger Condition                                           |
| ----------- | -------------------- | ----------------------------------------------------------- |
| Success     | `status-success`     | `state == 'active' AND status == 'success'`                 |
| Failure     | `status-failure`     | `state == 'active' AND status == 'failure'`                 |
| In Progress | `status-in-progress` | `state == 'active' AND status IN ('in_progress', 'queued')` |
| No Runs     | `status-no-runs`     | `state == 'active' AND status == 'unknown'`                 |
| Disabled    | `status-disabled`    | `state == 'disabled'`                                       |
| Unknown     | `status-unknown`     | Default fallback                                            |

### Jenkins Jobs

| Status    | CSS Class         | Trigger Condition                                                  |
| --------- | ----------------- | ------------------------------------------------------------------ |
| Success   | `status-success`  | `color IN ('blue', 'blue_anime') OR status == 'success'`           |
| Failure   | `status-failure`  | `color IN ('red', 'red_anime') OR status == 'failure'`             |
| Warning   | `status-warning`  | `color IN ('yellow', 'yellow_anime') OR status == 'unstable'`      |
| Building  | `status-building` | `'_anime' in color OR status == 'building'`                        |
| Aborted   | `status-aborted`  | `color IN ('aborted', 'aborted_anime')`                            |
| Not Built | `status-unknown`  | `color IN ('notbuilt', 'notbuilt_anime') OR status == 'not_built'` |
| Disabled  | `status-disabled` | `color == 'disabled'`                                              |

---

## Impact

### What Changed

✅ CI/CD Jobs table now matches production format
✅ Jobs grouped by Gerrit project
✅ Color-coded status indicators
✅ Hyperlinked job/workflow names

### What Stayed the Same

✅ Underlying JSON data structure unchanged
✅ Data collection process unchanged
✅ API integrations unchanged
✅ Backward compatibility maintained with legacy `all` field

---

## Next Steps

1. **Run full integration test** with real ONAP data
2. **Compare output** to production `report.html`
3. **Verify CSS styling** for status classes exists in theme
4. **Update documentation** if additional status classes are needed
5. **Add unit tests** for the new grouping logic

---

## Files Modified

- `src/rendering/context.py` - Added repository grouping logic
- `src/templates/html/sections/workflows.html.j2` - Complete rewrite for production format
- `src/templates/markdown/sections/workflows.md.j2` - Updated for production format
- `docs/CICD_TABLE_FIX.md` - This documentation

---

## Related Issues

- Thread: [Gerrit Reporting Tool Documentation Updates](zed://agent/thread/2a86412b-d89b-46e1-8b5d-2272084cec29)
- Production system reference: `project-reporting-tool/src/project_reporting_tool/renderers/report.py`
