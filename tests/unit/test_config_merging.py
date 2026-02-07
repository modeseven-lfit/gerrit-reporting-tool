# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""
Unit tests for configuration merging and override behavior.

Tests the deep_merge_dicts function and load_configuration behavior
to ensure project configurations properly override default values while
inheriting all non-overridden values.
"""

from project_reporting_tool.config import (
    deep_merge_dicts,
    load_configuration,
)


class TestDeepMergeDicts:
    """Test deep_merge_dicts function behavior."""

    def test_merge_empty_dicts(self):
        """Test merging two empty dictionaries."""
        base = {}
        override = {}
        result = deep_merge_dicts(base, override)
        assert result == {}

    def test_merge_empty_override(self):
        """Test merging with empty override keeps base values."""
        base = {"key": "value", "num": 42}
        override = {}
        result = deep_merge_dicts(base, override)
        assert result == base
        assert result == {"key": "value", "num": 42}

    def test_merge_empty_base(self):
        """Test merging with empty base uses override values."""
        base = {}
        override = {"key": "value", "num": 42}
        result = deep_merge_dicts(base, override)
        assert result == override
        assert result == {"key": "value", "num": 42}

    def test_simple_value_override(self):
        """Test that simple values are overridden completely."""
        base = {"project": "default", "log_level": "INFO"}
        override = {"project": "MyProject"}
        result = deep_merge_dicts(base, override)

        assert result["project"] == "MyProject"  # Overridden
        assert result["log_level"] == "INFO"  # Inherited

    def test_nested_dict_merge(self):
        """Test that nested dictionaries are merged, not replaced."""
        base = {
            "activity_thresholds": {"current_days": 365, "active_days": 1095, "inactive_days": 1825}
        }
        override = {
            "activity_thresholds": {
                "current_days": 183,
                "active_days": 548,
                # inactive_days not specified
            }
        }
        result = deep_merge_dicts(base, override)

        assert result["activity_thresholds"]["current_days"] == 183  # Overridden
        assert result["activity_thresholds"]["active_days"] == 548  # Overridden
        assert result["activity_thresholds"]["inactive_days"] == 1825  # Inherited

    def test_deep_nested_merge(self):
        """Test deeply nested dictionary merging."""
        base = {
            "api": {
                "github": {
                    "enabled": True,
                    "token_env_var": "GITHUB_TOKEN",
                    "entries_per_page": 100,
                }
            }
        }
        override = {"api": {"github": {"token_env_var": "MY_CUSTOM_TOKEN"}}}
        result = deep_merge_dicts(base, override)

        assert result["api"]["github"]["enabled"] is True  # Inherited
        assert result["api"]["github"]["token_env_var"] == "MY_CUSTOM_TOKEN"  # Overridden
        assert result["api"]["github"]["entries_per_page"] == 100  # Inherited

    def test_list_replacement(self):
        """Test that lists are replaced entirely, not merged."""
        base = {"output_formats": ["json", "markdown", "html"]}
        override = {"output_formats": ["json", "markdown"]}
        result = deep_merge_dicts(base, override)

        # List should be replaced, not merged
        assert result["output_formats"] == ["json", "markdown"]
        assert "html" not in result["output_formats"]

    def test_null_value_override(self):
        """Test that null values in override actually override (not skip)."""
        base = {"some_value": "hello", "another_value": 42}
        override = {"some_value": None}
        result = deep_merge_dicts(base, override)

        assert result["some_value"] is None  # Explicitly set to null
        assert result["another_value"] == 42  # Inherited

    def test_mixed_types_override(self):
        """Test overriding with different types."""
        base = {"value": "string"}
        override = {
            "value": 42  # Change from string to int
        }
        result = deep_merge_dicts(base, override)

        assert result["value"] == 42
        assert isinstance(result["value"], int)

    def test_add_new_keys(self):
        """Test that override can add new keys not in base."""
        base = {"existing": "value"}
        override = {"new_key": "new_value", "another_new": 42}
        result = deep_merge_dicts(base, override)

        assert result["existing"] == "value"
        assert result["new_key"] == "new_value"
        assert result["another_new"] == 42

    def test_complex_merge_scenario(self):
        """Test a complex real-world merge scenario."""
        base = {
            "project": "default",
            "activity_thresholds": {"current_days": 365, "active_days": 1095},
            "time_windows": {
                "last_30": {"days": 30},
                "last_90": {"days": 90},
                "last_365": {"days": 365},
            },
            "api": {
                "github": {"enabled": True, "token_env_var": "GITHUB_TOKEN"},
                "gerrit": {"enabled": True, "host": "gerrit.example.org"},
            },
        }

        override = {
            "project": "OpenDaylight",
            "activity_thresholds": {"current_days": 183, "active_days": 548},
            "api": {"gerrit": {"host": "gerrit.opendaylight.org"}},
        }

        result = deep_merge_dicts(base, override)

        # Project overridden
        assert result["project"] == "OpenDaylight"

        # Activity thresholds partially overridden
        assert result["activity_thresholds"]["current_days"] == 183
        assert result["activity_thresholds"]["active_days"] == 548

        # Time windows completely inherited
        assert result["time_windows"] == base["time_windows"]

        # API settings partially overridden
        assert result["api"]["github"]["enabled"] is True
        assert result["api"]["github"]["token_env_var"] == "GITHUB_TOKEN"
        assert result["api"]["gerrit"]["enabled"] is True
        assert result["api"]["gerrit"]["host"] == "gerrit.opendaylight.org"

    def test_original_dicts_unchanged(self):
        """Test that original dictionaries are not modified."""
        base = {"key": "base_value", "nested": {"inner": "base"}}
        override = {"key": "override_value", "nested": {"inner": "override"}}

        # Store original values
        base_key_original = base["key"]
        override_key_original = override["key"]

        result = deep_merge_dicts(base, override)

        # Original dicts should be unchanged
        assert base["key"] == base_key_original
        assert override["key"] == override_key_original

        # Result should have merged values
        assert result["key"] == "override_value"


class TestLoadConfiguration:
    """Test load_configuration function with real config files."""

    def test_load_default_only(self, tmp_path):
        """Test loading when only default.yaml exists."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        # Create default.yaml
        default_config = {
            "project": "default",
            "activity_thresholds": {"current_days": 365, "active_days": 1095},
        }
        import yaml

        (config_dir / "default.yaml").write_text(yaml.dump(default_config))

        # Load configuration for non-existent project
        result = load_configuration(project="nonexistent", config_dir=config_dir)

        # Should use defaults
        assert result["project"] == "nonexistent"  # Project name set to requested
        assert result["activity_thresholds"]["current_days"] == 365

    def test_load_with_project_override(self, tmp_path):
        """Test loading with project-specific override."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        # Create default.yaml
        default_config = {
            "project": "default",
            "activity_thresholds": {"current_days": 365, "active_days": 1095},
            "time_windows": {"last_30": {"days": 30}, "last_90": {"days": 90}},
        }

        # Create project-specific override
        project_config = {"project": "MyProject", "activity_thresholds": {"current_days": 183}}

        import yaml

        (config_dir / "default.yaml").write_text(yaml.dump(default_config))
        (config_dir / "myproject.yaml").write_text(yaml.dump(project_config))

        # Load configuration
        result = load_configuration(project="myproject", config_dir=config_dir)

        # Verify merge
        assert result["project"] == "myproject"  # Set by load_configuration
        assert result["activity_thresholds"]["current_days"] == 183  # Overridden
        assert result["activity_thresholds"]["active_days"] == 1095  # Inherited
        assert result["time_windows"]["last_30"]["days"] == 30  # Inherited
        assert result["time_windows"]["last_90"]["days"] == 90  # Inherited

    def test_load_opendaylight_config(self, tmp_path):
        """Test loading actual OpenDaylight-style minimal config."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        # Create comprehensive default.yaml
        default_config = {
            "project": "default",
            "activity_thresholds": {"current_days": 365, "active_days": 1095},
            "time_windows": {
                "last_30": {"days": 30},
                "last_90": {"days": 90},
                "last_365": {"days": 365},
                "last_3_years": {"days": 1095},
            },
            "api": {"github": {"enabled": True}, "gerrit": {"enabled": True}},
            "features": {"ci_cd": {"enabled": True}, "documentation": {"enabled": True}},
        }

        # Create minimal OpenDaylight override (like the real one)
        opendaylight_config = {
            "project": "OpenDaylight",
            "activity_thresholds": {"current_days": 183, "active_days": 548},
        }

        import yaml

        (config_dir / "default.yaml").write_text(yaml.dump(default_config))
        (config_dir / "opendaylight.yaml").write_text(yaml.dump(opendaylight_config))

        # Load configuration
        result = load_configuration(project="opendaylight", config_dir=config_dir)

        # Verify OpenDaylight overrides
        assert result["project"] == "opendaylight"
        assert result["activity_thresholds"]["current_days"] == 183
        assert result["activity_thresholds"]["active_days"] == 548

        # Verify inherited values
        assert result["time_windows"]["last_30"]["days"] == 30
        assert result["time_windows"]["last_90"]["days"] == 90
        assert result["time_windows"]["last_365"]["days"] == 365
        assert result["time_windows"]["last_3_years"]["days"] == 1095
        assert result["api"]["github"]["enabled"] is True
        assert result["api"]["gerrit"]["enabled"] is True
        assert result["features"]["ci_cd"]["enabled"] is True
        assert result["features"]["documentation"]["enabled"] is True

    def test_missing_default_config(self, tmp_path):
        """Test handling when default.yaml is missing."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        # Don't create default.yaml
        # Create project config
        project_config = {"project": "MyProject"}
        import yaml

        (config_dir / "myproject.yaml").write_text(yaml.dump(project_config))

        # Should still work with empty defaults
        result = load_configuration(project="myproject", config_dir=config_dir)

        assert result["project"] == "myproject"

    def test_backward_compatibility_config_extension(self, tmp_path):
        """Test backward compatibility with .config extension."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        # Create default.yaml
        default_config = {"project": "default", "value": 1}

        # Create project.config (old style)
        project_config = {"project": "MyProject", "value": 2}

        import yaml

        (config_dir / "default.yaml").write_text(yaml.dump(default_config))
        (config_dir / "myproject.config").write_text(yaml.dump(project_config))

        # Should find .config file
        result = load_configuration(project="myproject", config_dir=config_dir)

        assert result["value"] == 2  # From .config file

    def test_yaml_preferred_over_config(self, tmp_path):
        """Test that .yaml is preferred over .config when both exist."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        default_config = {"project": "default", "value": 1}
        yaml_config = {"project": "MyProject", "value": 2}
        old_config = {"project": "MyProject", "value": 3}

        import yaml

        (config_dir / "default.yaml").write_text(yaml.dump(default_config))
        (config_dir / "myproject.yaml").write_text(yaml.dump(yaml_config))
        (config_dir / "myproject.config").write_text(yaml.dump(old_config))

        result = load_configuration(project="myproject", config_dir=config_dir)

        # Should use .yaml (value=2), not .config (value=3)
        assert result["value"] == 2

    def test_custom_default_config_name(self, tmp_path):
        """Test using a custom default config filename."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()

        # Create custom-named default
        default_config = {"project": "default", "value": 1}

        import yaml

        (config_dir / "custom-defaults.yaml").write_text(yaml.dump(default_config))

        result = load_configuration(
            project="myproject", config_dir=config_dir, default_config_name="custom-defaults.yaml"
        )

        assert result["value"] == 1
        assert result["project"] == "myproject"


class TestConfigurationMergingEdgeCases:
    """Test edge cases and error conditions."""

    def test_none_values_in_base(self):
        """Test handling None values in base config."""
        base = {"key": None, "other": "value"}
        override = {"key": "override"}
        result = deep_merge_dicts(base, override)

        assert result["key"] == "override"
        assert result["other"] == "value"

    def test_none_values_in_override(self):
        """Test handling None values in override config."""
        base = {"key": "base", "other": "value"}
        override = {"key": None}
        result = deep_merge_dicts(base, override)

        assert result["key"] is None
        assert result["other"] == "value"

    def test_boolean_values(self):
        """Test handling boolean values correctly."""
        base = {"enabled": True, "debug": False}
        override = {"enabled": False}
        result = deep_merge_dicts(base, override)

        assert result["enabled"] is False
        assert result["debug"] is False

    def test_numeric_zero_values(self):
        """Test that zero values are not treated as falsy/missing."""
        base = {"count": 10, "timeout": 30}
        override = {"count": 0}
        result = deep_merge_dicts(base, override)

        assert result["count"] == 0  # Should be 0, not 10
        assert result["timeout"] == 30

    def test_empty_string_values(self):
        """Test handling empty strings."""
        base = {"name": "default", "value": "something"}
        override = {"name": ""}
        result = deep_merge_dicts(base, override)

        assert result["name"] == ""  # Empty string is valid
        assert result["value"] == "something"

    def test_nested_empty_dicts(self):
        """Test handling nested empty dictionaries."""
        base = {"section": {"subsection": {"value": 1}}}
        override = {"section": {}}
        result = deep_merge_dicts(base, override)

        # Empty dict should not remove nested values
        assert result["section"]["subsection"]["value"] == 1
