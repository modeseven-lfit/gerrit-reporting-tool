<!--
SPDX-FileCopyrightText: 2024 Linux Foundation

SPDX-License-Identifier: Apache-2.0
-->

# GitHub Language Comparison Tool

This document describes the GitHub language comparison tool that helps align our local project type detection with GitHub's language detection (powered by Linguist).

## Overview

The `compare_github_languages.py` script fetches language/project type data from GitHub for all repositories in an organization and compares it with our local detection results. This helps identify:

- **Gaps** - Languages GitHub detects that we miss
- **Mismatches** - Different primary language/type classifications
- **Alignment opportunities** - Where we can improve our detection logic
- **Success metrics** - How well our detection matches GitHub's

## Why Compare with GitHub?

GitHub uses [Linguist](https://github.com/github-linguist/linguist), a sophisticated language detection library that:

- Analyzes file content, not just extensions
- Uses a comprehensive database of language definitions
- Has weighted scoring for different file types
- Ignores vendored code, generated files, and documentation
- Is battle-tested across millions of repositories

Aligning with GitHub's detection ensures:

1. **Consistency** - Users see the same language classifications on GitHub and in reports
2. **Accuracy** - Leverage GitHub's proven detection algorithms
3. **Completeness** - Detect all languages GitHub recognizes

## Prerequisites

1. **GitHub Personal Access Token** with `repo` or `public_repo` scope
   - Create at: <https://github.com/settings/tokens>
   - For public repos only, use `public_repo` scope
   - For private repos, use `repo` scope

2. **Python dependencies**:

   ```bash
   pip install httpx
   ```

3. **Optional: Cloned repositories** for local analysis
   - If you want to compare local detection, clone repos first
   - Or use existing cloned repositories

## Usage

### Basic: GitHub-Only Analysis

Fetch language data from GitHub without local comparison:

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN
```

This will:

- Fetch all repositories in the organization
- Get language statistics for each repository
- Show GitHub's language detection results
- Save to JSON if `--output` is specified

### Full Comparison with Local Detection

Compare GitHub's detection with our local analysis:

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN \
    --repos-path ./repos
```

This will:

- Fetch GitHub language data
- Analyze local repositories in `./repos`
- Compare the results
- Generate detailed comparison report

### Save Detailed Results

Save full comparison data to JSON:

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN \
    --repos-path ./repos \
    --output comparison_results.json
```

### With Debug Logging

Get detailed logging output:

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN \
    --repos-path ./repos \
    --log-level DEBUG
```

## Output Format

### Console Report

The script generates a human-readable report with:

```text
================================================================================
GitHub vs Local Language Detection Comparison
================================================================================

Summary:
  Total GitHub repos: 245
  Analyzed locally: 183
  Exact matches: 156
  Partial matches: 8
  Complete mismatches: 19
  No local data: 62
```

Match Percentages:
  Exact matches: 71.7%
  Partial matches: 15.7%
  Mismatches: 12.6%

Languages with Good Agreement:
  (GitHub primary language matched our detection)
  Python: 89 repos
  Java: 42 repos
  JavaScript: 18 repos
  Go: 12 repos
  ...

Language Detection Gaps:
  (GitHub detected but we missed as primary)
  Shell: 8 repos
  Makefile: 5 repos
  Dockerfile: 3 repos
  ...

Sample Mismatches (first 10):
  Repository: example-repo
    GitHub primary: Python
    Our primary: Dockerfile
    GitHub languages: Python, Dockerfile, Shell
    Our types: Dockerfile, Python
  ...

```text

### JSON Output

The `--output` file contains detailed data:

```json
{
  "github_data": {
    "repo-name": {
      "full_name": "org/repo-name",
      "html_url": "https://github.com/org/repo-name",
      "github_primary_language": "Python",
      "languages": {
        "Python": 125000,
        "Shell": 3500,
        "Dockerfile": 500
      },
      "calculated_primary": "Python",
      "total_bytes": 129000,
      "archived": false,
      "fork": false
    }
  },
  "local_data": {
    "repo-name": {
      "detected_types": ["Python", "Dockerfile", "Shell"],
      "primary_type": "Python",
      "details": [
        {
          "type": "Python",
          "files": ["setup.py", "main.py"],
          "confidence": 2
        }
      ]
    }
  },
  "comparison": {
    "total_repos": 245,
    "analyzed_locally": 198,
    "matches": [...],
    "mismatches": [...],
    "statistics": {...}
  }
}
```

## Understanding the Results

### Match Types

1. **Exact Match**
   - GitHub's primary language matches our primary type
   - Best case scenario
   - Example: GitHub=Python, Our=Python

2. **Partial Match**
   - GitHub's primary is in our detected types, but not primary
   - We detected it, but prioritized differently
   - Example: GitHub=Python, Our primary=Dockerfile, detected=[Dockerfile, Python]

3. **Complete Mismatch**
   - GitHub's primary language not in our detected types
   - Indicates missing detection or significant discrepancy
   - Example: GitHub=Python, Our=[Java, Dockerfile]

### Interpreting Statistics

**High Exact Match %** (>70%)

- Good alignment with GitHub
- Minor tweaks may improve further

**High Partial Match %** (>20%)

- Detection works but prioritization differs
- Review confidence scoring logic
- Consider GitHub's byte-count weighting

**High Mismatch %** (>15%)

- Significant detection gaps
- Add missing language patterns
- Review file detection logic

## Common Issues and Solutions

### Issue: Low Exact Match Percentage

**Causes:**

- Confidence scoring differs from GitHub's byte-count approach
- Missing file patterns for certain languages
- Over-detection of infrastructure files (Dockerfile, Makefile)

**Solutions:**

1. Adjust confidence scoring to weight actual code files more heavily
2. Add missing file extensions from gaps report
3. Consider ignoring or de-prioritizing infrastructure files

### Issue: "Shell" or "Makefile" as GitHub Primary

**Cause:**

- Repository has more build/script files than application code
- GitHub prioritizes by byte count

**Solution:**

- This might be correct (e.g., shell script projects)
- Or adjust confidence to favor application code over build scripts

### Issue: Language Gaps in Report

**Cause:**

- We don't detect certain languages GitHub recognizes

**Solution:**

1. Check if language is in our `project_types` dictionary
2. Add missing patterns from GitHub Linguist
3. Add tests for the new language

### Issue: Different Primary for Multi-Language Repos

**Cause:**

- Complex repos (e.g., Python backend + React frontend)
- Different weighting strategies

**Solution:**

- Document expected behavior
- May be acceptable divergence
- Or adjust confidence scoring

## Improving Detection Alignment

### Step 1: Analyze Gap Report

Look at "Language Detection Gaps" section:

```text
Language Detection Gaps:
  Shell: 8 repos
  Makefile: 5 repos
  CMake: 3 repos
```

### Step 2: Check if We Detect These

For each language in gaps:

- Check if it's in `src/project_reporting_tool/features/registry.py`
- If missing, add it with appropriate patterns
- If present, check if patterns match GitHub's

### Step 3: Review Mismatch Samples

Examine specific mismatches:

- Clone the repository
- Look at file structure
- Understand why GitHub chose its primary
- Adjust our detection logic accordingly

### Step 4: Adjust Confidence Scoring

Consider GitHub's approach:

- They use byte counts (more code = higher weight)
- We use file counts (more files = higher weight)

You might want to:

- Weight by file size instead of count
- Prioritize actual source code over config files
- De-prioritize generated files

### Step 5: Add Tests

For each improved detection:

- Add test in `tests/unit/test_project_type_detection.py`
- Verify against known repositories
- Document expected behavior

## ONAP-Specific Considerations

### Repository Structure

ONAP repositories often have:

- Multiple languages (Python, Java, Go)
- Heavy use of YAML, JSON for configuration
- Docker, Kubernetes manifests
- Shell scripts for tooling
- Documentation in reStructuredText

### Expected Patterns

Based on ONAP's architecture:

- **Python**: ML/AI components, tooling, testing
- **Java**: Core components, SDN-C, APPC
- **Go**: Cloud-native services, integration
- **JavaScript/TypeScript**: UI components (Portal, SDC)
- **Dockerfile**: Container definitions (very common)

### Comparison Goals

For ONAP, aim for:

- 70%+ exact match rate
- <15% complete mismatch rate
- Good agreement on: Python, Java, Go, JavaScript

## Example Workflow

### 1. Initial Analysis

```bash
# Fetch GitHub data
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN \
    --output github_baseline.json
```

### 2. Clone Representative Repos

```bash
# Clone a subset for testing
mkdir -p repos
cd repos
git clone https://github.com/onap/policy-engine
git clone https://github.com/onap/portal
git clone https://github.com/onap/so
# ... etc
cd ..
```

### 3. Run Comparison

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN \
    --repos-path ./repos \
    --output comparison.json
```

### 4. Analyze Results

Review the report and identify top mismatches.

### 5. Improve Detection

Edit `src/project_reporting_tool/features/registry.py` based on gaps.

### 6. Test Changes

```bash
pytest tests/unit/test_project_type_detection.py -v
```

### 7. Re-run Comparison

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --github-token $GITHUB_TOKEN \
    --repos-path ./repos
```

### 8. Verify Improvement

Compare statistics before and after changes.

## API Rate Limits

GitHub API has rate limits:

- **Authenticated**: 5,000 requests/hour
- **Unauthenticated**: 60 requests/hour

The script makes:

- 1 request per page of repos (~1-3 for most orgs)
- 1 request per repository for languages

For ONAP (~245 repos):

- Total requests: ~250
- Well within rate limits
- Runtime: ~2-3 minutes

## Security Considerations

1. **Token Security**
   - Never commit tokens to git
   - Use environment variables
   - Rotate tokens regularly

2. **Token Permissions**
   - Use minimal required scope
   - For public repos: `public_repo`
   - For private repos: `repo`

3. **Data Privacy**
   - GitHub data is public for public repos
   - Don't expose private repo data
   - Be careful with output files

## Troubleshooting

### Error: "httpx package is required"

```bash
pip install httpx
```

### Error: "No module named 'project_reporting_tool'"

Run from repository root or install package:

```bash
pip install -e .
```

### Error: "401 Unauthorized"

- Check token is valid
- Verify token has required permissions
- Check token hasn't expired

### Error: "403 Rate Limit Exceeded"

- Wait for rate limit to reset
- Check current limits: `curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit`

### Warning: "No local data"

- Ensure `--repos-path` points to correct directory
- Verify repositories are cloned
- Check directory names match GitHub repo names

## Further Reading

- [GitHub Linguist Documentation](https://github.com/github-linguist/linguist)
- [GitHub Languages API](https://docs.github.com/en/rest/repos/repos#list-repository-languages)
- [GitHub Rate Limiting](https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api)
- [Project Type Detection Documentation](PROJECT_TYPE_DETECTION.md)
