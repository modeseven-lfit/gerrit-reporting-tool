# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""
Integration test for OpenDaylight G2G regex pattern matching.

This test validates that the OpenDaylight configuration with regex patterns
correctly detects all three workflow files in the OpenDaylight project.
"""

import logging
from pathlib import Path

import pytest
import yaml

from gerrit_reporting_tool.features.registry import FeatureRegistry


@pytest.fixture
def logger():
    """Create a logger for testing."""
    return logging.getLogger(__name__)


@pytest.fixture
def opendaylight_config():
    """Load the actual OpenDaylight configuration file."""
    config_path = Path(__file__).parent.parent.parent / "configuration" / "opendaylight.yaml"
    with open(config_path) as f:
        return yaml.safe_load(f)


@pytest.fixture
def mock_opendaylight_repo(tmp_path: Path) -> Path:
    """
    Create a mock OpenDaylight repository structure with all three workflow files.

    This simulates the actual OpenDaylight repository structure.
    """
    repo_path = tmp_path / "opendaylight-repo"
    repo_path.mkdir()

    workflows_dir = repo_path / ".github" / "workflows"
    workflows_dir.mkdir(parents=True)

    # Create the three actual workflow files used by OpenDaylight
    workflows = [
        "github2gerrit.yaml",
        "call-github2gerrit.yaml",
        "call-composed-github2gerrit.yaml",
    ]

    for workflow in workflows:
        workflow_path = workflows_dir / workflow
        workflow_path.write_text(f"# OpenDaylight workflow: {workflow}\nname: {workflow}\n")

    # Add some other workflows that should NOT be detected
    other_workflows = [
        "ci-verify.yaml",
        "release.yaml",
        "maven-build.yaml",
    ]

    for workflow in other_workflows:
        workflow_path = workflows_dir / workflow
        workflow_path.write_text(f"# Other workflow: {workflow}\nname: {workflow}\n")

    return repo_path


class TestOpenDaylightG2GConfiguration:
    """Integration tests for OpenDaylight G2G configuration."""

    def test_opendaylight_config_uses_regex_pattern(self, opendaylight_config: dict):
        """Verify that OpenDaylight configuration uses regex pattern."""
        features = opendaylight_config.get("features", {})
        g2g_config = features.get("g2g", {})
        workflow_files = g2g_config.get("workflow_files", [])

        # Should have at least one entry
        assert len(workflow_files) > 0

        # Should use regex pattern
        assert any(
            isinstance(pattern, str) and pattern.startswith("regex:") for pattern in workflow_files
        ), "OpenDaylight config should use regex: prefix for pattern matching"

    def test_opendaylight_pattern_matches_all_three_workflows(
        self, mock_opendaylight_repo: Path, opendaylight_config: dict, logger: logging.Logger
    ):
        """Test that OpenDaylight regex pattern matches all three workflow files."""
        registry = FeatureRegistry(opendaylight_config, logger)
        result = registry._check_g2g(mock_opendaylight_repo)

        # Should detect g2g as present
        assert result["present"] is True

        # Should find exactly 3 workflow files
        assert len(result["file_paths"]) == 3, (
            f"Expected 3 workflow files, got {len(result['file_paths'])}: {result['file_paths']}"
        )

        # Verify specific files are detected
        expected_files = [
            ".github/workflows/call-composed-github2gerrit.yaml",
            ".github/workflows/call-github2gerrit.yaml",
            ".github/workflows/github2gerrit.yaml",
        ]

        # Sort both lists for comparison (implementation sorts them)
        assert sorted(result["file_paths"]) == sorted(expected_files)

    def test_opendaylight_pattern_does_not_match_other_workflows(
        self, mock_opendaylight_repo: Path, opendaylight_config: dict, logger: logging.Logger
    ):
        """Test that OpenDaylight pattern does not match unrelated workflows."""
        registry = FeatureRegistry(opendaylight_config, logger)
        result = registry._check_g2g(mock_opendaylight_repo)

        # Should NOT match these workflows
        excluded_workflows = [
            ".github/workflows/ci-verify.yaml",
            ".github/workflows/release.yaml",
            ".github/workflows/maven-build.yaml",
        ]

        for excluded in excluded_workflows:
            assert excluded not in result["file_paths"], (
                f"{excluded} should not be matched by g2g pattern"
            )

    def test_opendaylight_pattern_is_case_insensitive(
        self, tmp_path: Path, opendaylight_config: dict, logger: logging.Logger
    ):
        """Test that OpenDaylight pattern is case-insensitive."""
        repo_path = tmp_path / "test-repo"
        repo_path.mkdir()
        workflows_dir = repo_path / ".github" / "workflows"
        workflows_dir.mkdir(parents=True)

        # Create workflows with different case variations
        # Note: On case-insensitive filesystems (macOS, Windows), files with same name
        # but different case will overwrite each other, so we use unique prefixes
        case_variations = [
            "GITHUB2GERRIT-uppercase.yaml",
            "GitHub2Gerrit-mixedcase.yaml",
            "github2gerrit-lowercase.yaml",
            "Call-GitHub2Gerrit-workflow.yaml",
        ]

        for workflow in case_variations:
            (workflows_dir / workflow).write_text(f"name: {workflow}\n")

        registry = FeatureRegistry(opendaylight_config, logger)
        result = registry._check_g2g(repo_path)

        # All variations should be matched (case-insensitive)
        assert result["present"] is True
        assert len(result["file_paths"]) == len(case_variations), (
            f"Expected {len(case_variations)} files, got {len(result['file_paths'])}: {result['file_paths']}"
        )

    def test_opendaylight_pattern_with_no_workflows(
        self, tmp_path: Path, opendaylight_config: dict, logger: logging.Logger
    ):
        """Test OpenDaylight pattern when no g2g workflows exist."""
        repo_path = tmp_path / "empty-repo"
        repo_path.mkdir()
        workflows_dir = repo_path / ".github" / "workflows"
        workflows_dir.mkdir(parents=True)

        # Create only non-g2g workflows
        (workflows_dir / "ci.yaml").write_text("name: ci\n")
        (workflows_dir / "test.yaml").write_text("name: test\n")

        registry = FeatureRegistry(opendaylight_config, logger)
        result = registry._check_g2g(repo_path)

        # Should not detect g2g
        assert result["present"] is False
        assert result["file_paths"] == []

    def test_opendaylight_pattern_matches_composed_workflow(
        self, tmp_path: Path, opendaylight_config: dict, logger: logging.Logger
    ):
        """Test that the pattern matches the composed workflow specifically."""
        repo_path = tmp_path / "test-repo"
        repo_path.mkdir()
        workflows_dir = repo_path / ".github" / "workflows"
        workflows_dir.mkdir(parents=True)

        # Create only the composed workflow
        (workflows_dir / "call-composed-github2gerrit.yaml").write_text("name: composed\n")

        registry = FeatureRegistry(opendaylight_config, logger)
        result = registry._check_g2g(repo_path)

        # Should detect it
        assert result["present"] is True
        assert ".github/workflows/call-composed-github2gerrit.yaml" in result["file_paths"]

    def test_matched_patterns_metadata(
        self, mock_opendaylight_repo: Path, opendaylight_config: dict, logger: logging.Logger
    ):
        """Test that matched_patterns metadata is populated correctly."""
        registry = FeatureRegistry(opendaylight_config, logger)
        result = registry._check_g2g(mock_opendaylight_repo)

        # Verify matched_patterns exists in result
        assert "matched_patterns" in result
        assert isinstance(result["matched_patterns"], dict)

        # Should have at least one pattern that matched
        assert len(result["matched_patterns"]) > 0

        # Each pattern should have a list of matched files
        for pattern, matched_files in result["matched_patterns"].items():
            assert isinstance(matched_files, list)
            assert len(matched_files) > 0
            # Pattern should start with "regex:" for regex patterns
            if pattern.startswith("regex:"):
                assert len(matched_files) == 3  # Should match all 3 g2g workflows


class TestOpenDaylightConfigurationValidation:
    """Validation tests for OpenDaylight configuration structure."""

    def test_opendaylight_config_structure(self, opendaylight_config: dict):
        """Validate the structure of OpenDaylight configuration."""
        # Verify required top-level keys
        assert "project" in opendaylight_config
        assert opendaylight_config["project"] == "OpenDaylight"

        # Verify features section exists
        assert "features" in opendaylight_config
        assert "g2g" in opendaylight_config["features"]

        # Verify g2g configuration
        g2g_config = opendaylight_config["features"]["g2g"]
        assert "workflow_files" in g2g_config
        assert isinstance(g2g_config["workflow_files"], list)

    def test_opendaylight_regex_pattern_is_valid(self, opendaylight_config: dict):
        """Validate that the regex pattern in OpenDaylight config is valid."""
        import re

        g2g_config = opendaylight_config["features"]["g2g"]
        workflow_files = g2g_config["workflow_files"]

        for pattern in workflow_files:
            if isinstance(pattern, str) and pattern.startswith("regex:"):
                regex_str = pattern[6:]  # Remove "regex:" prefix
                try:
                    # Try to compile the regex
                    compiled = re.compile(regex_str, re.IGNORECASE)
                    assert compiled is not None
                except re.error as e:
                    pytest.fail(f"Invalid regex pattern in OpenDaylight config: {regex_str} - {e}")

    def test_opendaylight_pattern_specificity(self, opendaylight_config: dict):
        """Test that the OpenDaylight pattern is appropriately specific."""
        import re

        g2g_config = opendaylight_config["features"]["g2g"]
        workflow_files = g2g_config["workflow_files"]

        # Get the regex pattern
        regex_patterns = [
            p[6:] for p in workflow_files if isinstance(p, str) and p.startswith("regex:")
        ]

        assert len(regex_patterns) > 0, "Should have at least one regex pattern"

        # Test pattern against various filenames
        for regex_str in regex_patterns:
            pattern = re.compile(regex_str, re.IGNORECASE)

            # Should match these
            should_match = [
                "github2gerrit.yaml",
                "call-github2gerrit.yaml",
                "call-composed-github2gerrit.yaml",
                "GitHub2Gerrit.yaml",  # Case variation
                "my-github2gerrit-workflow.yaml",  # With prefix/suffix
            ]

            # Should NOT match these
            should_not_match = [
                "ci.yaml",
                "test.yaml",
                "gerrit.yaml",  # Missing "github2"
                "github2gitlab.yaml",  # Wrong target
                "github.yaml",
                "release.yaml",
            ]

            for filename in should_match:
                assert pattern.search(filename), f"Pattern '{regex_str}' should match '{filename}'"

            for filename in should_not_match:
                assert not pattern.search(filename), (
                    f"Pattern '{regex_str}' should NOT match '{filename}'"
                )
