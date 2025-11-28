<!--
SPDX-FileCopyrightText: 2024 Linux Foundation

SPDX-License-Identifier: Apache-2.0
-->

# Quick Start: GitHub Language Comparison

This guide shows you how to compare GitHub's language detection with our local project type detection for ONAP repositories.

## Prerequisites

1. **GitHub Token**: Create a personal access token at <https://github.com/settings/tokens>
   - For public repos (ONAP), select the `public_repo` scope
   - Save the token securely

2. **Install Dependencies**:

   ```bash
   pip install httpx
   pip install -e .
   ```

## Quick Examples

### Example 1: Fetch GitHub Language Data

Get language statistics from GitHub for all ONAP repositories:

```bash
export GITHUB_TOKEN="your_token_here"

python scripts/compare_github_languages.py \
    --org onap \
    --output onap_github_languages.json
```

**Output**: Console report + JSON file with all GitHub language data

**Use case**: Quick overview of what languages GitHub detects across ONAP

---

### Example 2: Compare with Local Repositories

If you have ONAP repos cloned locally, compare GitHub's detection with ours:

```bash
export GITHUB_TOKEN="your_token_here"

python scripts/compare_github_languages.py \
    --org onap \
    --repos-path /path/to/onap/repos \
    --output onap_comparison.json
```

**Output**: Detailed comparison report + JSON with alignment analysis

**Use case**: Identify where our detection differs from GitHub's

---

### Example 3: Debug Specific Issues

Get detailed logging to troubleshoot detection problems:

```bash
export GITHUB_TOKEN="your_token_here"

python scripts/compare_github_languages.py \
    --org onap \
    --repos-path ./repos \
    --log-level DEBUG \
    --output debug_comparison.json
```

**Output**: Verbose logging + full comparison data

**Use case**: Investigate why specific repos have mismatched classifications

---

## Understanding the Output

### Console Report

```text
================================================================================
GitHub vs Local Language Detection Comparison
================================================================================

Summary:
  Total GitHub repos: 245
  Analyzed locally: 198
  Exact matches: 142
  Partial matches: 31
  Complete mismatches: 25
  No local data: 47

Match Percentages:
  Exact matches: 71.7%        ✓ Good alignment
  Partial matches: 15.7%      ⚠ Detection works, prioritization differs
  Mismatches: 12.6%           ✗ Need improvement

Languages with Good Agreement:
  Python: 89 repos            ✓ Our Python detection aligns well
  Java: 42 repos              ✓ Our Java detection aligns well
  JavaScript: 18 repos        ✓ Our JavaScript detection aligns well

Language Detection Gaps:
  Shell: 8 repos              ⚠ We're missing Shell as primary in these repos
  Makefile: 5 repos           ⚠ We're missing Makefile detection
  CMake: 3 repos              ⚠ We're not prioritizing CMake as expected
```

### What the Numbers Mean

- **Exact Match**: GitHub's primary = Our primary (Best!)
- **Partial Match**: We detected it, but prioritized differently
- **Mismatch**: We missed GitHub's primary language

**Target Goals:**

- Exact match: >70%
- Partial match: <20%
- Mismatch: <15%

---

## Common Scenarios

### Scenario 1: You Don't Have Repos Cloned

**Fetch GitHub data first:**

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --output github_baseline.json
```

This gives you a baseline of what GitHub sees. Review the JSON to understand:

- What languages are most common
- Which repos use which languages
- Language byte counts and distributions

### Scenario 2: You Have Some Repos Cloned

**Run comparison on what you have:**

```bash
python scripts/compare_github_languages.py \
    --org onap \
    --repos-path ./repos \
    --output partial_comparison.json
```

The script will:

- Compare repos you have locally
- Report on repos missing from local analysis
- Still show full GitHub statistics

### Scenario 3: Investigating Specific Mismatches

**Focus on repos with mismatches:**

1. Run full comparison:

   ```bash
   python scripts/compare_github_languages.py \
       --org onap \
       --repos-path ./repos \
       --output full_comparison.json
   ```

2. Look at the "Sample Mismatches" section in output

3. Clone specific repos with issues:

   ```bash
   cd repos
   git clone https://github.com/onap/problematic-repo
   ```

4. Test local detection:

   ```python
   from pathlib import Path
   from gerrit_reporting_tool.features.registry import FeatureRegistry
   import logging

   config = {"features": {"enabled": ["project_types"]}}
   registry = FeatureRegistry(config, logging.getLogger())
   result = registry._check_project_types(Path("./repos/problematic-repo"))
   print(result)
   ```

5. Compare with GitHub's detection in JSON output

---

## Reading the JSON Output

The output JSON has three main sections:

### 1. `github_data`

What GitHub detected for each repository:

```json
{
  "policy-engine": {
    "full_name": "onap/policy-engine",
    "github_primary_language": "Java",
    "languages": {
      "Java": 2500000,
      "Python": 50000,
      "Shell": 10000
    },
    "calculated_primary": "Java",
    "total_bytes": 2560000
  }
}
```

### 2. `local_data`

What our detection found:

```json
{
  "policy-engine": {
    "detected_types": ["Java", "Python", "Dockerfile"],
    "primary_type": "Java",
    "details": [
      {
        "type": "Java",
        "files": ["pom.xml", "Main.java"],
        "confidence": 2
      }
    ]
  }
}
```

### 3. `comparison`

Analysis of matches and mismatches:

```json
{
  "statistics": {
    "exact_matches": 142,
    "partial_matches": 31,
    "complete_mismatches": 25,
    "exact_match_percentage": 71.7
  },
  "language_agreement": {
    "Python": 89,
    "Java": 42
  },
  "language_gaps": {
    "Shell": 8,
    "Makefile": 5
  }
}
```

---

## Next Steps After Running Comparison

### If Match Rate is Good (>70%)

✓ Your detection is well-aligned!

**Minor improvements:**

- Review partial matches to improve prioritization
- Add any missing languages from gaps report
- Document known acceptable differences

### If Match Rate is Medium (50-70%)

⚠ Some alignment needed

**Recommended actions:**

1. Review "Language Detection Gaps" section
2. Add missing language patterns
3. Adjust confidence scoring
4. Test on sample repos
5. Re-run comparison

### If Match Rate is Low (<50%)

✗ Significant alignment needed

**Required actions:**

1. Audit detection logic in `registry.py`
2. Compare file patterns with [GitHub Linguist](https://github.com/github-linguist/linguist/blob/master/lib/linguist/languages.yml)
3. Review confidence scoring algorithm
4. Consider byte-count weighting vs file-count
5. Add comprehensive tests
6. Re-run comparison after changes

---

## Tips for ONAP

### Expected Languages in ONAP

Based on ONAP's architecture, you should see:

- **Java**: Policy, APPC, SDNC, SO components
- **Python**: Testing, tooling, VVP, AI/ML components
- **JavaScript/TypeScript**: Portal, SDC UI
- **Go**: Some cloud-native services
- **Dockerfile**: Common (containerized architecture)
- **Shell**: Build scripts, deployment tooling
- **YAML**: Configuration, Kubernetes manifests

### ONAP-Specific Considerations

- **Multi-language repos**: ONAP repos often use 2-3 languages

2. **Infrastructure code**: Lots of Docker, Kubernetes, Helm

- **Build systems**: Maven, Gradle are common

4. **Test frameworks**: Robot Framework widely used

### Realistic Goals for ONAP

- Exact match: 65-75% (multi-language repos make this challenging)
- Partial match: 15-25% (expected for mixed repos)
- Mismatch: 10-15% (acceptable for edge cases)

---

## Troubleshooting

### "No module named 'httpx'"

```bash
pip install httpx
```

### "No module named 'gerrit_reporting_tool'"

```bash
pip install -e .
```

### "401 Unauthorized"

- Check your GitHub token is valid
- Verify it has `public_repo` scope
- Try: `curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user`

### "Rate limit exceeded"

- Wait 1 hour for reset
- Check limits: `curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit`

### "No local data for repo X"

- Ensure the repo exists in `--repos-path`
- Check directory name matches GitHub repo name
- Verify path is correct

---

## Full Documentation

See [GITHUB_LANGUAGE_COMPARISON.md](../docs/GITHUB_LANGUAGE_COMPARISON.md) for:

- Detailed usage examples
- Advanced analysis techniques
- Improving detection alignment
- Understanding GitHub's detection
- API reference

---

## Questions?

1. Check the full documentation: `docs/GITHUB_LANGUAGE_COMPARISON.md`
2. Review GitHub Linguist: <https://github.com/github-linguist/linguist>
3. See project type detection: `docs/PROJECT_TYPE_DETECTION.md`
