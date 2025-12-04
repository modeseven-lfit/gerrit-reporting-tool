<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# G2G Workflow Detection with Regex Patterns

## Overview

The GitHub2Gerrit (G2G) feature detection system supports flexible workflow file matching using both exact filenames and regular expression patterns. This allows project configurations to match multiple workflow files with a single pattern, reducing maintenance overhead and providing more flexible detection rules.

## Configuration

### Basic Configuration

The G2G workflow detection is configured in project-specific YAML files under the `features.g2g.workflow_files` section:

```yaml
features:
  g2g:
    workflow_files:
      - "github2gerrit.yaml"
      - "call-github2gerrit.yaml"
```

### Regex Pattern Matching

To use regex pattern matching, prefix the pattern with `regex:`:

```yaml
features:
  g2g:
    workflow_files:
      - "regex:.*github2gerrit.*"
```

This pattern will match any workflow file containing "github2gerrit" in its name, including:

- `github2gerrit.yaml`
- `call-github2gerrit.yaml`
- `call-composed-github2gerrit.yaml`
- `my-github2gerrit-workflow.yaml`
- `github2gerrit-v2.yml`

### Mixed Configuration

You can combine exact filenames with regex patterns:

```yaml
features:
  g2g:
    workflow_files:
      - "exact-workflow.yaml"           # Exact match
      - "regex:.*github2gerrit.*"       # Pattern match
      - "another-exact-workflow.yml"    # Exact match
```

## Pattern Syntax

### Case Sensitivity

By default, regex patterns are **case-insensitive**. This means:

```yaml
workflow_files:
  - "regex:.*github2gerrit.*"
```

Will match all of these:

- `github2gerrit.yaml`
- `GitHub2Gerrit.yaml`
- `GITHUB2GERRIT.yaml`
- `call-GITHUB2Gerrit-workflow.yaml`

To enable case-sensitive matching, use the `(?-i)` flag at the start of your pattern:

```yaml
workflow_files:
  - "regex:(?-i)^github2gerrit\\.yaml$"  # Only matches lowercase
```

### Common Patterns

#### Match Any File Containing Text

```yaml
workflow_files:
  - "regex:.*github2gerrit.*"
```

Matches: Any file with "github2gerrit" anywhere in the name

#### Match Specific Extensions

```yaml
workflow_files:
  - "regex:.*github2gerrit\\.ya?ml$"
```

Matches: Files ending with `.yaml` or `.yml`

#### Exact Match with Anchors

```yaml
workflow_files:
  - "regex:^github2gerrit\\.yaml$"
```

Matches: Only `github2gerrit.yaml` (exact match)

#### Multiple Alternatives (OR)

```yaml
workflow_files:
  - "regex:^(github2gerrit|call-github2gerrit|call-composed-github2gerrit)\\.yaml$"
```

Matches: Exactly these three files and no others

#### Prefix or Suffix Matching

```yaml
workflow_files:
  - "regex:^g2g-.*\\.yaml$"      # Starts with "g2g-"
  - "regex:.*-gerrit-sync\\.yaml$"  # Ends with "-gerrit-sync.yaml"
```

#### Version Patterns

```yaml
workflow_files:
  - "regex:github2gerrit-v\\d+\\.\\d+\\.yaml"
```

Matches: `github2gerrit-v1.0.yaml`, `github2gerrit-v2.3.yaml`, etc.

## Real-World Examples

### OpenDaylight Configuration

OpenDaylight uses a single regex pattern to match all three of its G2G workflow files:

```yaml
# configuration/opendaylight.yaml
features:
  g2g:
    workflow_files:
      - "regex:.*github2gerrit.*"
```

This matches:

- `github2gerrit.yaml`
- `call-github2gerrit.yaml`
- `call-composed-github2gerrit.yaml`

**Before** (explicit list - required updates when new workflows added):

```yaml
features:
  g2g:
    workflow_files:
      - "github2gerrit.yaml"
      - "call-github2gerrit.yaml"
      - "call-composed-github2gerrit.yaml"  # Had to be added manually
```

**After** (regex pattern - automatically matches new workflows):

```yaml
features:
  g2g:
    workflow_files:
      - "regex:.*github2gerrit.*"  # Automatically matches any new g2g workflows
```

### Multi-Pattern Configuration

For projects with different naming conventions:

```yaml
features:
  g2g:
    workflow_files:
      - "regex:.*github2gerrit.*"
      - "regex:.*gerrit-sync.*"
      - "regex:.*mirror.*gerrit.*"
```

### Restrictive Pattern

To match only official workflow names:

```yaml
features:
  g2g:
    workflow_files:
      - "regex:^(github2gerrit|call-github2gerrit)\\.ya?ml$"
```

This ensures only approved workflow names are matched.

## Behavior and Edge Cases

### Pattern Matching Scope

- Patterns only match files directly in `.github/workflows/`
- Subdirectories within `workflows/` are **not** searched
- Hidden files (starting with `.`) are ignored

### Duplicate Matches

If a file matches multiple patterns, it will only appear once in the results:

```yaml
workflow_files:
  - "regex:.*github2gerrit.*"
  - "regex:^github2gerrit\\.yaml$"
  - "regex:.*\\.yaml$"
```

If `github2gerrit.yaml` exists, it appears only once in the matched files list, even though it matches all three patterns.

### Invalid Regex Handling

If a regex pattern is invalid, it will be logged as a warning and skipped. Other patterns will continue to be processed:

```yaml
workflow_files:
  - "regex:[invalid(regex"      # Invalid - will be skipped with warning
  - "regex:.*github2gerrit.*"   # Valid - will be processed
```

### Empty Configuration

An empty `workflow_files` list means no files will be matched:

```yaml
features:
  g2g:
    workflow_files: []  # No files will be matched
```

If `workflow_files` is not specified, the system falls back to default behavior:

- Default: `["github2gerrit.yaml", "call-github2gerrit.yaml"]`

### Result Structure

The detection result includes metadata about pattern matching:

```python
{
    "present": True,  # Whether any g2g workflows were found
    "file_paths": [   # List of matched workflow files
        ".github/workflows/github2gerrit.yaml",
        ".github/workflows/call-github2gerrit.yaml"
    ],
    "file_path": ".github/workflows/github2gerrit.yaml",  # First match (backward compatibility)
    "matched_patterns": {  # Which patterns matched which files
        "regex:.*github2gerrit.*": [
            "github2gerrit.yaml",
            "call-github2gerrit.yaml"
        ]
    }
}
```

## Migration Guide

### From Explicit Lists to Regex Patterns

**Step 1: Analyze Current Configuration**

Current configuration:

```yaml
features:
  g2g:
    workflow_files:
      - "github2gerrit.yaml"
      - "call-github2gerrit.yaml"
      - "call-composed-github2gerrit.yaml"
```

**Step 2: Identify Common Pattern**

All files contain "github2gerrit" → Use pattern `.*github2gerrit.*`

**Step 3: Update Configuration**

```yaml
features:
  g2g:
    workflow_files:
      - "regex:.*github2gerrit.*"
```

**Step 4: Test Configuration**

Run tests or use the feature detection to verify all expected files are matched.

### Validation Checklist

Before deploying regex patterns to production:

1. ✅ **Pattern Validity**: Ensure regex compiles without errors
2. ✅ **Positive Matches**: Verify all expected files are matched
3. ✅ **Negative Matches**: Verify unwanted files are NOT matched
4. ✅ **Case Sensitivity**: Test with different case variations if needed
5. ✅ **Edge Cases**: Test with edge cases (special chars, unicode, etc.)

## Best Practices

### 1. Start Simple

Use the simplest pattern that matches your needs:

```yaml
# Good: Simple and clear
workflow_files:
  - "regex:.*github2gerrit.*"

# Avoid: Overly complex when not needed
workflow_files:
  - "regex:^(?:github2gerrit|call-github2gerrit|.*github2gerrit.*)\\.ya?ml$"
```

### 2. Be Specific Enough

Avoid patterns that are too broad:

```yaml
# Too broad: Matches ALL workflow files
workflow_files:
  - "regex:.*"

# Better: Matches only g2g workflows
workflow_files:
  - "regex:.*github2gerrit.*"
```

### 3. Document Your Patterns

Add comments explaining what the pattern matches:

```yaml
features:
  g2g:
    # Match any workflow file containing "github2gerrit"
    # This includes: github2gerrit.yaml, call-github2gerrit.yaml, etc.
    workflow_files:
      - "regex:.*github2gerrit.*"
```

### 4. Test Thoroughly

Create test cases for your patterns to ensure they work as expected:

```python
# Test that pattern matches expected files
assert matches("github2gerrit.yaml")
assert matches("call-github2gerrit.yaml")
assert matches("call-composed-github2gerrit.yaml")

# Test that pattern doesn't match unwanted files
assert not matches("ci-verify.yaml")
assert not matches("release.yaml")
```

### 5. Consider Future-Proofing

Design patterns that will match new workflows following the same naming convention:

```yaml
# Future-proof: Will match new github2gerrit workflows automatically
workflow_files:
  - "regex:.*github2gerrit.*"

# Not future-proof: Requires updates for new workflows
workflow_files:
  - "github2gerrit.yaml"
  - "call-github2gerrit.yaml"
```

## Troubleshooting

### Pattern Not Matching Expected Files

1. **Check the regex syntax**: Use an online regex tester (regex101.com)
2. **Verify case sensitivity**: Remember patterns are case-insensitive by default
3. **Check file location**: Files must be in `.github/workflows/`, not subdirectories
4. **Review logs**: Look for warnings about invalid patterns

### Pattern Matching Too Many Files

1. **Make pattern more specific**: Add anchors (`^` and `$`) or more specific text
2. **Use exact matches**: Consider using exact filenames instead of patterns
3. **Test the pattern**: Use regex tester with your actual filenames

### Backward Compatibility Issues

The regex feature is fully backward compatible:

- Existing exact filename configurations continue to work
- No changes required for projects using exact filenames
- Mixed configurations (exact + regex) are supported

## Performance Considerations

- Regex pattern matching scans all files in `.github/workflows/`
- Performance impact is minimal for typical repositories (< 100 workflow files)
- Patterns are compiled once and cached during detection
- Invalid patterns are skipped after logging a warning

## Security Considerations

- Regex patterns are evaluated locally (no remote code execution)
- Patterns are compiled with default Python `re` module flags
- Invalid patterns fail safely (logged and skipped)
- No risk of regex denial-of-service (ReDoS) in normal usage
- Patterns only match filenames, not file contents

## API Reference

### Configuration Schema

```yaml
features:
  g2g:
    workflow_files:
      - string | "regex:<pattern>"  # List of exact filenames or regex patterns
```

### Regex Pattern Format

- **Prefix**: `regex:` (required for pattern matching)
- **Pattern**: Standard Python regex syntax
- **Flags**: Case-insensitive by default (`re.IGNORECASE`)
- **Override**: Use `(?-i)` in pattern for case-sensitive matching

### Return Value

```python
{
    "present": bool,              # True if any workflows matched
    "file_paths": List[str],      # List of matched workflow file paths
    "file_path": Optional[str],   # First matched file (backward compatibility)
    "matched_patterns": Dict[str, List[str]]  # Pattern → matched files mapping
}
```

## Testing

The regex pattern feature includes comprehensive test coverage:

- **Unit Tests**: 41 tests in `tests/unit/test_g2g_feature.py`
- **Integration Tests**: 10 tests in `tests/integration/test_g2g_opendaylight.py`
- **Coverage Areas**:
  - Pattern syntax validation
  - Case sensitivity
  - Multiple patterns
  - Mixed exact/regex configuration
  - Edge cases and error handling
  - OpenDaylight-specific use cases

Run tests:

```bash
pytest tests/unit/test_g2g_feature.py -v
pytest tests/integration/test_g2g_opendaylight.py -v
```

## Support

For questions or issues:

1. Check this documentation
2. Review test cases for examples
3. Contact the development team
4. File an issue in the project repository

## Version History

- **v1.0.0** (2025-01): Initial release of regex pattern matching support
  - Added `regex:` prefix for pattern matching
  - Case-insensitive matching by default
  - Full backward compatibility with exact filename matching
  - Comprehensive test coverage (51 tests)
  - Updated OpenDaylight configuration to use regex patterns
