# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""
Unit tests for G2G (GitHub2Gerrit) feature detection with configurable workflow files.

Tests verify:
- Default workflow file detection (github2gerrit.yaml, call-github2gerrit.yaml)
- Custom workflow file configuration
- Single custom workflow file
- Multiple custom workflow files
- Backward compatibility when no configuration is provided
"""

import logging
from pathlib import Path
from typing import Any

import pytest

from gerrit_reporting_tool.features.registry import FeatureRegistry


@pytest.fixture
def logger():
    """Create a logger for testing."""
    return logging.getLogger(__name__)


@pytest.fixture
def temp_repo(tmp_path: Path) -> Path:
    """Create a temporary repository structure."""
    repo_path = tmp_path / "test-repo"
    repo_path.mkdir()
    workflows_dir = repo_path / ".github" / "workflows"
    workflows_dir.mkdir(parents=True)
    return repo_path


def create_workflow_file(repo_path: Path, filename: str) -> None:
    """Create a workflow file in the repository."""
    workflow_path = repo_path / ".github" / "workflows" / filename
    workflow_path.write_text("# Test workflow\n")


class TestG2GFeatureDefaults:
    """Test G2G feature detection with default configuration."""

    def test_no_workflow_files_found(self, temp_repo: Path, logger: logging.Logger):
        """Test that G2G is not detected when no workflow files exist."""
        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is False
        assert result["file_paths"] == []
        assert result["file_path"] is None

    def test_github2gerrit_yaml_detected(self, temp_repo: Path, logger: logging.Logger):
        """Test that github2gerrit.yaml is detected by default."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/github2gerrit.yaml" in result["file_paths"]
        assert result["file_path"] == ".github/workflows/github2gerrit.yaml"

    def test_call_github2gerrit_yaml_detected(self, temp_repo: Path, logger: logging.Logger):
        """Test that call-github2gerrit.yaml is detected by default."""
        create_workflow_file(temp_repo, "call-github2gerrit.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/call-github2gerrit.yaml" in result["file_paths"]
        assert result["file_path"] == ".github/workflows/call-github2gerrit.yaml"

    def test_both_default_workflows_detected(self, temp_repo: Path, logger: logging.Logger):
        """Test that both default workflow files are detected when present."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")
        create_workflow_file(temp_repo, "call-github2gerrit.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert len(result["file_paths"]) == 2
        assert ".github/workflows/github2gerrit.yaml" in result["file_paths"]
        assert ".github/workflows/call-github2gerrit.yaml" in result["file_paths"]

    def test_non_default_workflow_not_detected(self, temp_repo: Path, logger: logging.Logger):
        """Test that non-default workflow files are not detected without config."""
        create_workflow_file(temp_repo, "custom-gerrit-sync.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is False
        assert result["file_paths"] == []


class TestG2GFeatureCustomConfiguration:
    """Test G2G feature detection with custom workflow file configuration."""

    def test_single_custom_workflow_detected(self, temp_repo: Path, logger: logging.Logger):
        """Test detection with a single custom workflow filename."""
        create_workflow_file(temp_repo, "sync-to-gerrit.yaml")

        config: dict[str, Any] = {
            "features": {"enabled": ["g2g"], "g2g": {"workflow_files": ["sync-to-gerrit.yaml"]}}
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/sync-to-gerrit.yaml" in result["file_paths"]

    def test_multiple_custom_workflows_detected(self, temp_repo: Path, logger: logging.Logger):
        """Test detection with multiple custom workflow filenames."""
        create_workflow_file(temp_repo, "gerrit-sync.yaml")
        create_workflow_file(temp_repo, "mirror-to-gerrit.yaml")

        config: dict[str, Any] = {
            "features": {
                "enabled": ["g2g"],
                "g2g": {
                    "workflow_files": [
                        "gerrit-sync.yaml",
                        "mirror-to-gerrit.yaml",
                        "another-workflow.yaml",
                    ]
                },
            }
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert len(result["file_paths"]) == 2
        assert ".github/workflows/gerrit-sync.yaml" in result["file_paths"]
        assert ".github/workflows/mirror-to-gerrit.yaml" in result["file_paths"]

    def test_custom_config_overrides_defaults(self, temp_repo: Path, logger: logging.Logger):
        """Test that custom configuration completely overrides defaults."""
        # Create default workflow file
        create_workflow_file(temp_repo, "github2gerrit.yaml")

        # Configure only a custom workflow
        config: dict[str, Any] = {
            "features": {"enabled": ["g2g"], "g2g": {"workflow_files": ["custom-workflow.yaml"]}}
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        # Should not detect the default file since we overrode the config
        assert result["present"] is False
        assert result["file_paths"] == []

    def test_mix_of_default_and_custom_workflows(self, temp_repo: Path, logger: logging.Logger):
        """Test configuration with both default and custom workflow names."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")
        create_workflow_file(temp_repo, "custom-sync.yaml")

        config: dict[str, Any] = {
            "features": {
                "enabled": ["g2g"],
                "g2g": {
                    "workflow_files": [
                        "github2gerrit.yaml",
                        "call-github2gerrit.yaml",
                        "custom-sync.yaml",
                    ]
                },
            }
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert len(result["file_paths"]) == 2
        assert ".github/workflows/github2gerrit.yaml" in result["file_paths"]
        assert ".github/workflows/custom-sync.yaml" in result["file_paths"]

    def test_any_match_is_sufficient(self, temp_repo: Path, logger: logging.Logger):
        """Test that finding ANY configured workflow file marks G2G as present."""
        # Create only one of multiple configured workflows
        create_workflow_file(temp_repo, "workflow-b.yaml")

        config: dict[str, Any] = {
            "features": {
                "enabled": ["g2g"],
                "g2g": {
                    "workflow_files": ["workflow-a.yaml", "workflow-b.yaml", "workflow-c.yaml"]
                },
            }
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert len(result["file_paths"]) == 1
        assert ".github/workflows/workflow-b.yaml" in result["file_paths"]

    def test_string_workflow_file_converted_to_list(self, temp_repo: Path, logger: logging.Logger):
        """Test that a single string workflow_files value is converted to a list."""
        create_workflow_file(temp_repo, "single-workflow.yaml")

        config: dict[str, Any] = {
            "features": {"enabled": ["g2g"], "g2g": {"workflow_files": "single-workflow.yaml"}}
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/single-workflow.yaml" in result["file_paths"]


class TestG2GFeatureBackwardCompatibility:
    """Test backward compatibility of G2G feature detection."""

    def test_empty_config_uses_defaults(self, temp_repo: Path, logger: logging.Logger):
        """Test that empty config falls back to defaults."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")

        config: dict[str, Any] = {}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/github2gerrit.yaml" in result["file_paths"]

    def test_no_features_section_uses_defaults(self, temp_repo: Path, logger: logging.Logger):
        """Test that missing features section uses defaults."""
        create_workflow_file(temp_repo, "call-github2gerrit.yaml")

        config: dict[str, Any] = {"project": "test-project"}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/call-github2gerrit.yaml" in result["file_paths"]

    def test_empty_g2g_config_uses_defaults(self, temp_repo: Path, logger: logging.Logger):
        """Test that empty g2g config section uses defaults."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"], "g2g": {}}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/github2gerrit.yaml" in result["file_paths"]

    def test_result_structure_unchanged(self, temp_repo: Path, logger: logging.Logger):
        """Test that the result structure remains consistent."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        # Verify expected keys exist
        assert "present" in result
        assert "file_paths" in result
        assert "file_path" in result

        # Verify types
        assert isinstance(result["present"], bool)
        assert isinstance(result["file_paths"], list)
        assert isinstance(result["file_path"], str) or result["file_path"] is None


class TestG2GFeatureEdgeCases:
    """Test edge cases for G2G feature detection."""

    def test_workflows_directory_missing(self, temp_repo: Path, logger: logging.Logger):
        """Test that missing .github/workflows directory is handled gracefully."""
        # Remove the workflows directory
        import shutil

        workflows_dir = temp_repo / ".github" / "workflows"
        if workflows_dir.exists():
            shutil.rmtree(workflows_dir)

        config: dict[str, Any] = {"features": {"enabled": ["g2g"]}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is False
        assert result["file_paths"] == []

    def test_empty_workflow_files_list(self, temp_repo: Path, logger: logging.Logger):
        """Test behavior with empty workflow_files list."""
        create_workflow_file(temp_repo, "github2gerrit.yaml")

        config: dict[str, Any] = {"features": {"enabled": ["g2g"], "g2g": {"workflow_files": []}}}
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        # Empty list means nothing to check, so nothing found
        assert result["present"] is False
        assert result["file_paths"] == []

    def test_case_sensitive_matching(self, temp_repo: Path, logger: logging.Logger):
        """Test that workflow filename matching follows filesystem case sensitivity."""
        import platform

        create_workflow_file(temp_repo, "GitHub2Gerrit.yaml")

        config: dict[str, Any] = {
            "features": {"enabled": ["g2g"], "g2g": {"workflow_files": ["github2gerrit.yaml"]}}
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        # On case-insensitive filesystems (macOS, Windows), it will match
        # On case-sensitive filesystems (Linux), it will not match
        # We just verify the detection works based on filesystem behavior
        if platform.system() in ["Darwin", "Windows"]:
            # Case-insensitive filesystem
            assert result["present"] is True
        else:
            # Case-sensitive filesystem (Linux)
            assert result["present"] is False

    def test_whitespace_in_filename(self, temp_repo: Path, logger: logging.Logger):
        """Test handling of workflow filenames with whitespace."""
        create_workflow_file(temp_repo, "workflow with spaces.yaml")

        config: dict[str, Any] = {
            "features": {
                "enabled": ["g2g"],
                "g2g": {"workflow_files": ["workflow with spaces.yaml"]},
            }
        }
        registry = FeatureRegistry(config, logger)

        result = registry._check_g2g(temp_repo)

        assert result["present"] is True
        assert ".github/workflows/workflow with spaces.yaml" in result["file_paths"]
