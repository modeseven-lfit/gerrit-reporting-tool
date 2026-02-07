<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Configuration Merging and Override System

**How to create minimal project configurations that inherit from defaults**

---

## Overview

The reporting tool uses a **hierarchical configuration system** that allows project-specific configurations to override only the values that differ from the base defaults. This means you can create very simple project configuration files that only specify what's unique to your project.

### Key Benefits

- ✅ **Minimal configuration files** - Only specify what's different
- ✅ **Automatic inheritance** - All default values are automatically inherited
- ✅ **Deep merging** - Nested configurations merge intelligently
- ✅ **Easy maintenance** - Update defaults once, all projects benefit
- ✅ **No duplication** - DRY principle applied to configuration

---

## How It Works

### Configuration Loading Order

1. **Load `default.yaml`** - Base configuration with sensible defaults
2. **Load `{project}.yaml`** (optional) - Project-specific overrides
3. **Deep merge** - Combine configurations with project taking precedence
4. **Result** - Complete configuration with all values resolved

### Deep Merge Behavior

The merge process is **recursive** and **intelligent**:

```yaml
# default.yaml
activity_thresholds:
  current_days: 365
  active_days: 1095
time_windows:
  last_30: {days: 30}
  last_90: {days: 90}

# project.yaml
activity_thresholds:
  current_days: 183  # Override just this value

# MERGED RESULT
activity_thresholds:
  current_days: 183    # ← From project.yaml
  active_days: 1095    # ← From default.yaml (inherited!)
time_windows:
  last_30: {days: 30}  # ← From default.yaml (inherited!)
  last_90: {days: 90}  # ← From default.yaml (inherited!)
```

**Key Points:**

- Only `current_days` was overridden
- `active_days` was automatically inherited
- Entire `time_windows` section was inherited
- No need to redefine unchanged values

---

## Real-World Example: OpenDaylight

### Minimal Project Configuration

```yaml
# configuration/opendaylight.yaml
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

# OpenDaylight Project Configuration
# Only defines values that differ from default.yaml

project: OpenDaylight

# Activity thresholds - customized for OpenDaylight's release cycle
activity_thresholds:
  current_days: 183      # ✅ Current: ~6 months
  active_days: 548       # ☑️ Active: ~18 months
```

**That's it!** Just 14 lines including comments.

### What Gets Inherited Automatically

From `default.yaml`, OpenDaylight automatically inherits:

- ✅ All time windows (`last_30`, `last_90`, `last_365`, `last_3_years`)
- ✅ Output format settings
- ✅ API configuration (GitHub, Gerrit, Jenkins)
- ✅ Feature detection settings (CI/CD, documentation, security)
- ✅ Performance tuning parameters
- ✅ Privacy settings
- ✅ Logging configuration
- ✅ Cache settings
- ✅ And everything else in default.yaml!

### Verification

```bash
# View the resolved configuration
project-reporting-tool generate \
  --project OpenDaylight \
  --repos-path ./gerrit.opendaylight.org \
  --show-config \
  --dry-run
```

---

## Common Override Patterns

### Pattern 1: Custom Activity Thresholds

**Use case:** Project has different release cycles

```yaml
# configuration/myproject.yaml
project: MyProject

activity_thresholds:
  current_days: 90      # Faster-paced project
  active_days: 180
```

### Pattern 2: Enable Specific APIs

**Use case:** Project only uses GitHub (no Gerrit/Jenkins)

```yaml
# configuration/github-only-project.yaml
project: GitHubOnlyProject

api:
  github:
    enabled: true
  gerrit:
    enabled: false
  jenkins:
    enabled: false
```

### Pattern 3: Custom Feature Detection

**Use case:** Disable certain features

```yaml
# configuration/minimal-project.yaml
project: MinimalProject

features:
  ci_cd:
    enabled: false
  documentation:
    enabled: false
```

### Pattern 4: Partial Override

**Use case:** Override one nested value, inherit others

```yaml
# configuration/fast-project.yaml
project: FastProject

performance:
  workers: 16          # Override worker count
  # cache_enabled, git_optimization, etc. all inherited!
```

### Pattern 5: Add Custom Values

**Use case:** Add project-specific metadata

```yaml
# configuration/custom-project.yaml
project: CustomProject

# Override defaults
activity_thresholds:
  current_days: 183

# Add custom fields (won't conflict with defaults)
custom_metadata:
  team: "Infrastructure Team"
  slack_channel: "#project-reports"
```

---

## Best Practices

### ✅ DO

1. **Keep project configs minimal** - Only override what's necessary
2. **Document why you override** - Use comments to explain custom values
3. **Use descriptive project names** - Match your actual project name
4. **Test the merged result** - Use `--show-config` to verify
5. **Review defaults regularly** - You might not need overrides anymore

### ❌ DON'T

1. **Don't duplicate defaults** - If it's the same as default.yaml, remove it
2. **Don't override for no reason** - Have a clear rationale for each override
3. **Don't ignore default.yaml updates** - Stay aware of new defaults
4. **Don't create deep nesting unnecessarily** - Keep configs flat when possible

---

## Advanced Topics

### Merging Rules

The `deep_merge_dicts()` function follows these rules:

1. **Scalar values** (strings, numbers, booleans): **Override completely**

   ```yaml
   # default: current_days: 365
   # project: current_days: 183
   # result:  current_days: 183  ← Project wins
   ```

2. **Dictionaries**: **Merge recursively**

   ```yaml
   # default: activity_thresholds: {current_days: 365, active_days: 1095}
   # project: activity_thresholds: {current_days: 183}
   # result:  activity_thresholds: {current_days: 183, active_days: 1095}
   ```

3. **Lists**: **Override completely** (no list merging)

   ```yaml
   # default: formats: [json, markdown]
   # project: formats: [html]
   # result:  formats: [html]  ← Project replaces entire list
   ```

4. **Null values**: **Override is null** (removes the value)

   ```yaml
   # default: some_value: "hello"
   # project: some_value: null
   # result:  some_value: null  ← Explicitly set to null
   ```

### Merge Precedence

When values exist in both configurations:

**Project config ALWAYS wins**

```text
default.yaml < project.yaml
     ↑              ↑
   Base        Overrides
```

### No Project Config? No Problem

If `{project}.yaml` doesn't exist:

```python
# The tool automatically uses defaults
merged_config = default_config.copy()
```

Projects can run with **zero configuration** beyond `default.yaml`!

---

## Testing Your Configuration

### Method 1: Dry Run with Config Display

```bash
project-reporting-tool generate \
  --project OpenDaylight \
  --repos-path ./gerrit.opendaylight.org \
  --show-config \
  --dry-run
```

Shows the fully merged configuration without running analysis.

### Method 2: Programmatic Test

```python
from pathlib import Path
from project_reporting_tool.config import load_configuration

config = load_configuration(
    project='opendaylight',
    config_dir=Path('configuration')
)

print(f"Activity threshold: {config['activity_thresholds']['current_days']}")
print(f"Time windows: {config['time_windows']}")
```

### Method 3: Compare Configurations

```bash
# Show default config
cat configuration/default.yaml

# Show project config
cat configuration/opendaylight.yaml

# Show merged result
project-reporting-tool generate --project OpenDaylight --repos-path . --show-config --dry-run
```

---

## Migration from Legacy Configs

### Legacy Pattern (project-reports)

```config
# Old style: Everything duplicated in project.config
project: OpenDaylight
gerrit: gerrit.opendaylight.org
github: opendaylight
activity_thresholds:
  current_days: 183
  active_days: 548
time_windows:
  days: [7, 30, 90, 365]
output_formats:
  json: true
  markdown: true
# ... 50+ more lines ...
```

### Modern Pattern (project-reporting-tool)

```yaml
# New style: Only overrides in project.yaml
project: OpenDaylight

activity_thresholds:
  current_days: 183
  active_days: 548
# Done! Everything else inherited
```

**90% reduction in configuration size!**

---

## Troubleshooting

### Configuration Not Loading

**Problem:** Project config seems ignored

**Solution:**

```bash
# Check file exists
ls -la configuration/myproject.yaml

# Check file is valid YAML
cat configuration/myproject.yaml | python -m yaml

# Verify project name matches
grep "project:" configuration/myproject.yaml
```

### Values Not Overriding

**Problem:** Project values aren't taking effect

**Possible causes:**

1. Typo in field name (check against schema)
2. Wrong nesting level (use `--show-config` to debug)
3. File not saved (verify with `cat`)

### Unexpected Behavior

**Problem:** Merged config doesn't look right

**Debug steps:**

```bash
# 1. View default config
cat configuration/default.yaml

# 2. View project config
cat configuration/myproject.yaml

# 3. View merged result
project-reporting-tool generate --project myproject --repos-path . --show-config --dry-run

# 4. Enable debug logging
project-reporting-tool generate --project myproject --repos-path . --log-level DEBUG
```

---

## Related Documentation

- **[Configuration Guide](CONFIGURATION.md)** - Configuration wizard and templates
- **[Commands Reference](COMMANDS.md)** - CLI options and usage
- **[Getting Started](GETTING_STARTED.md)** - First-time setup
- **[FAQ](FAQ.md)** - Common questions

---

## Implementation Details

### Source Code

The merging logic is implemented in `src/project_reporting_tool/config.py`:

- `deep_merge_dicts()` - Recursive merge function
- `load_configuration()` - Configuration loading with merge
- `load_yaml_config()` - YAML file loader

### Schema Validation

Configuration is validated against JSON schema after merging:

- Schema: `config/schema.json`
- Validator: `src/config/validator.py`

This ensures merged configurations are always valid.

---

## Summary

The reporting tool's configuration system is designed for **minimal maintenance** and **maximum reusability**:

✅ **Default values** → `default.yaml` (maintained centrally)
✅ **Project customization** → `{project}.yaml` (minimal overrides)
✅ **Automatic merging** → Deep merge handled transparently
✅ **Full validation** → Schema ensures correctness
✅ **Zero config option** → Projects work with defaults alone

**Result:** Less configuration, more productivity! 🚀

---

## Questions?

- Check the [FAQ](FAQ.md)
- Review [Usage Examples](USAGE_EXAMPLES.md)
- Open an issue on GitHub
