#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""
Compare GitHub Language Detection with Local Project Type Detection

This script fetches language/project type data from GitHub for all repositories
in an organization and compares it with our local detection results to identify
gaps and alignment opportunities.

Usage:
    python scripts/compare_github_languages.py --org onap --github-token $GITHUB_TOKEN
    python scripts/compare_github_languages.py --org onap --github-token $GITHUB_TOKEN --repos-path ./repos
    python scripts/compare_github_languages.py --org onap --github-token $GITHUB_TOKEN --output comparison.json
"""

import argparse
import json
import logging
import os
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


try:
    import httpx
except ImportError:
    print("Error: httpx is required. Install with: pip install httpx")
    sys.exit(1)

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from project_reporting_tool.features.registry import FeatureRegistry


class GitHubLanguageAnalyzer:
    """Fetch and analyze GitHub language detection for repositories."""

    def __init__(self, token: str, timeout: float = 30.0):
        """Initialize GitHub API client."""
        self.token = token
        self.base_url = "https://api.github.com"
        self.client = httpx.Client(
            base_url=self.base_url,
            timeout=httpx.Timeout(timeout, connect=10.0),
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "project-reporting-tool/compare-languages",
            },
        )
        self.logger = logging.getLogger(__name__)

    def close(self):
        """Close the httpx client."""
        self.client.close()

    def get_organization_repos(self, org: str) -> list[dict[str, Any]]:
        """
        Fetch all repositories for an organization.

        Args:
            org: GitHub organization name

        Returns:
            List of repository information dicts
        """
        repos = []
        page = 1
        per_page = 100

        self.logger.info(f"Fetching repositories for organization: {org}")

        while True:
            try:
                response = self.client.get(
                    f"/orgs/{org}/repos",
                    params={"page": page, "per_page": per_page, "type": "all"},
                )
                response.raise_for_status()
                page_repos = response.json()

                if not page_repos:
                    break

                repos.extend(page_repos)
                self.logger.info(f"Fetched {len(repos)} repositories so far...")
                page += 1

            except httpx.HTTPStatusError as e:
                self.logger.error(f"HTTP error fetching repos: {e}")
                break
            except Exception as e:
                self.logger.error(f"Error fetching repos: {e}")
                break

        self.logger.info(f"Total repositories found: {len(repos)}")
        return repos

    def get_repository_languages(self, owner: str, repo: str) -> dict[str, int]:
        """
        Fetch language statistics for a repository.

        Args:
            owner: Repository owner/organization
            repo: Repository name

        Returns:
            Dict mapping language names to byte counts
        """
        try:
            response = self.client.get(f"/repos/{owner}/{repo}/languages")
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            self.logger.warning(f"HTTP error fetching languages for {owner}/{repo}: {e}")
            return {}
        except Exception as e:
            self.logger.warning(f"Error fetching languages for {owner}/{repo}: {e}")
            return {}

    def analyze_organization(self, org: str) -> dict[str, dict[str, Any]]:
        """
        Analyze all repositories in an organization.

        Args:
            org: GitHub organization name

        Returns:
            Dict mapping repo names to their language data
        """
        repos = self.get_organization_repos(org)
        results = {}

        for repo in repos:
            repo_name = repo["name"]
            self.logger.debug(f"Fetching languages for {repo_name}")

            languages = self.get_repository_languages(org, repo_name)

            # Calculate primary language (most bytes)
            primary_language = None
            if languages:
                primary_language = max(languages.items(), key=lambda x: x[1])[0]

            results[repo_name] = {
                "full_name": repo["full_name"],
                "html_url": repo["html_url"],
                "github_primary_language": repo.get("language"),  # GitHub's reported primary
                "languages": languages,
                "calculated_primary": primary_language,
                "total_bytes": sum(languages.values()),
                "archived": repo.get("archived", False),
                "fork": repo.get("fork", False),
            }

        return results


class LocalProjectTypeAnalyzer:
    """Analyze project types using local detection."""

    def __init__(self):
        """Initialize local analyzer."""
        self.logger = logging.getLogger(__name__)
        config = {"features": {"enabled": ["project_types"]}}
        self.registry = FeatureRegistry(config, self.logger)

    def analyze_repository(self, repo_path: Path) -> dict[str, Any]:
        """
        Analyze a local repository.

        Args:
            repo_path: Path to repository

        Returns:
            Dict with detected project types
        """
        if not repo_path.exists():
            return {
                "error": "Repository path not found",
                "detected_types": [],
                "primary_type": None,
            }

        try:
            result = self.registry._check_project_types(repo_path)
            return result
        except Exception as e:
            self.logger.error(f"Error analyzing {repo_path}: {e}")
            return {
                "error": str(e),
                "detected_types": [],
                "primary_type": None,
            }

    def find_repository_path(self, base_path: Path, github_repo_name: str) -> Path | None:
        """
        Find repository path supporting both flat and Gerrit-style structures.

        GitHub repo names like "aai-aai-common" map to Gerrit structure like:
        - /base/aai/aai-common  (Gerrit style: project/subproject)
        - /base/aai-aai-common  (flat style)

        Args:
            base_path: Base directory containing repositories
            github_repo_name: GitHub repository name (e.g., "aai-aai-common")

        Returns:
            Path to repository if found, None otherwise
        """
        # Try flat structure first
        flat_path = base_path / github_repo_name
        if flat_path.exists() and flat_path.is_dir():
            return flat_path

        # Try Gerrit-style structure (project/subproject)
        # GitHub name format: {project}-{subproject} or variations
        parts = github_repo_name.split("-", 1)
        if len(parts) == 2:
            project, subproject = parts
            gerrit_path = base_path / project / subproject
            if gerrit_path.exists() and gerrit_path.is_dir():
                return gerrit_path

        # For repos with multiple hyphens, try different splits
        # e.g., "aai-aai-common" -> try "aai/aai-common"
        parts = github_repo_name.split("-")
        if len(parts) > 2:
            for i in range(1, len(parts)):
                project = "-".join(parts[:i])
                subproject = "-".join(parts[i:])
                gerrit_path = base_path / project / subproject
                if gerrit_path.exists() and gerrit_path.is_dir():
                    return gerrit_path

        return None

    def analyze_repositories(
        self, repos_path: Path, repo_names: list[str]
    ) -> dict[str, dict[str, Any]]:
        """
        Analyze multiple local repositories.

        Args:
            repos_path: Base path containing repositories
            repo_names: List of repository names to analyze

        Returns:
            Dict mapping repo names to detection results (only for repos found locally)
        """
        results = {}

        for repo_name in repo_names:
            # Try to find repo in Gerrit-style or flat structure
            repo_path = self.find_repository_path(repos_path, repo_name)

            if repo_path:
                self.logger.debug(f"Analyzing local repository: {repo_name} at {repo_path}")
                results[repo_name] = self.analyze_repository(repo_path)
            else:
                self.logger.debug(f"Repository not found locally, skipping: {repo_name}")
                # Don't add to results - we only want repos that exist locally

        return results


class LanguageComparisonAnalyzer:
    """Compare GitHub and local language detection."""

    def __init__(self):
        """Initialize comparison analyzer."""
        self.logger = logging.getLogger(__name__)

    @staticmethod
    def normalize_language_name(name: str) -> str:
        """
        Normalize language names for comparison.

        Args:
            name: Language or project type name

        Returns:
            Normalized name
        """
        # First, handle our combined types (Java/Maven, Java/Gradle) -> Java
        if name and "/" in name and name.startswith("Java/"):
            return "Java"

        # Mapping from GitHub names to our names
        name_mapping = {
            "Dockerfile": "Dockerfile",
            "JavaScript": "JavaScript",
            "TypeScript": "TypeScript",
            "Python": "Python",
            "Java": "Java",
            "C++": "C++",
            "C": "C",
            "Go": "Go",
            "Rust": "Rust",
            "Ruby": "Ruby",
            "PHP": "PHP",
            "Shell": "Shell",
            "HTML": "HTML",
            "CSS": "CSS",
            "SCSS": "SCSS",
            "Groovy": "Groovy",
            "Kotlin": "Kotlin",
            "Scala": "Scala",
            "Swift": "Swift",
            "Clojure": "Clojure",
            "Erlang": "Erlang",
            "Lua": "Lua",
            "D": "D",
            "HCL": "HCL",
            "Smarty": "Smarty",
            "EJS": "EJS",
            "RobotFramework": "Robot Framework",
            "Robot Framework": "Robot Framework",
            ".NET": ".NET",
            "C#": ".NET",
            "CMake": "C++",
            "Makefile": "C",
            "Maven": "Java",
            "Gradle": "Java",
        }

        return name_mapping.get(name, name)

    def compare_repositories(
        self,
        github_data: dict[str, dict[str, Any]],
        local_data: dict[str, dict[str, Any]],
    ) -> dict[str, Any]:
        """
        Compare GitHub and local detection results.

        Args:
            github_data: GitHub language data
            local_data: Local detection data

        Returns:
            Comparison analysis
        """
        comparison = {
            "total_repos": len(github_data),
            "matches": [],
            "mismatches": [],
            "github_only": [],
            "local_only": [],
            "statistics": {
                "exact_matches": 0,
                "partial_matches": 0,
                "complete_mismatches": 0,
                "skipped_not_local": 0,
                "analyzed_locally": 0,
            },
            "language_gaps": defaultdict(int),
            "language_agreement": defaultdict(int),
        }

        for repo_name, gh_data in github_data.items():
            # Skip archived and forked repos
            if gh_data.get("archived") or gh_data.get("fork"):
                continue

            local_result = local_data.get(repo_name)

            # Skip repos not found locally (archived/removed repos)
            if not local_result:
                comparison["statistics"]["skipped_not_local"] += 1
                self.logger.debug(f"Skipping {repo_name} - not found locally")
                continue

            # Count repos analyzed locally (excluding archived/forked)
            comparison["statistics"]["analyzed_locally"] += 1

            # Get GitHub's primary language
            gh_primary = gh_data.get("github_primary_language")
            gh_languages = set(gh_data.get("languages", {}).keys())

            # Get our detected types
            local_primary = local_result.get("primary_type")
            local_types = set(local_result.get("detected_types", []))

            # Normalize names for comparison
            gh_primary_norm = self.normalize_language_name(gh_primary) if gh_primary else None
            local_primary_norm = (
                self.normalize_language_name(local_primary) if local_primary else None
            )
            local_types_norm = {self.normalize_language_name(t) for t in local_types}

            # Compare
            if gh_primary_norm and gh_primary_norm == local_primary_norm:
                comparison["statistics"]["exact_matches"] += 1
                comparison["language_agreement"][gh_primary_norm] += 1
                comparison["matches"].append(
                    {
                        "repo": repo_name,
                        "language": gh_primary_norm,
                        "github_languages": list(gh_languages),
                        "local_types": list(local_types),
                    }
                )
            elif gh_primary_norm and gh_primary_norm in local_types_norm:
                comparison["statistics"]["partial_matches"] += 1
                comparison["language_agreement"][gh_primary_norm] += 1
                comparison["matches"].append(
                    {
                        "repo": repo_name,
                        "language": gh_primary_norm,
                        "match_type": "partial",
                        "github_primary": gh_primary,
                        "local_primary": local_primary,
                        "github_languages": list(gh_languages),
                        "local_types": list(local_types),
                    }
                )
            else:
                comparison["statistics"]["complete_mismatches"] += 1
                comparison["mismatches"].append(
                    {
                        "repo": repo_name,
                        "github_primary": gh_primary,
                        "local_primary": local_primary,
                        "github_languages": list(gh_languages),
                        "local_types": list(local_types),
                    }
                )

                # Track gaps
                if gh_primary:
                    comparison["language_gaps"][gh_primary] += 1

        # Calculate percentages
        analyzed = comparison["statistics"]["analyzed_locally"]

        # Add analyzed_locally to top level for easy access
        comparison["analyzed_locally"] = comparison["statistics"]["analyzed_locally"]

        if analyzed > 0:
            comparison["statistics"]["exact_match_percentage"] = (
                comparison["statistics"]["exact_matches"] / analyzed * 100
            )
            comparison["statistics"]["partial_match_percentage"] = (
                comparison["statistics"]["partial_matches"] / analyzed * 100
            )
            comparison["statistics"]["mismatch_percentage"] = (
                comparison["statistics"]["complete_mismatches"] / analyzed * 100
            )

        return comparison

    def generate_report(self, comparison: dict[str, Any]) -> str:
        """
        Generate a human-readable comparison report.

        Args:
            comparison: Comparison analysis

        Returns:
            Formatted report text
        """
        report_lines = [
            "=" * 80,
            "GitHub vs Local Language Detection Comparison",
            "=" * 80,
            "",
            "Summary:",
            f"  Total GitHub repos: {comparison['total_repos']}",
            f"  Skipped (not found locally): {comparison['statistics']['skipped_not_local']}",
            f"  Analyzed locally: {comparison['statistics']['analyzed_locally']}",
            "",
            "Results for locally available repos:",
            f"  Exact matches: {comparison['statistics']['exact_matches']}",
            f"  Partial matches: {comparison['statistics']['partial_matches']}",
            f"  Complete mismatches: {comparison['statistics']['complete_mismatches']}",
            "",
        ]

        if comparison["statistics"]["analyzed_locally"] > 0:
            report_lines.extend(
                [
                    "Match Percentages:",
                    f"  Exact matches: {comparison['statistics'].get('exact_match_percentage', 0):.1f}%",
                    f"  Partial matches: {comparison['statistics'].get('partial_match_percentage', 0):.1f}%",
                    f"  Mismatches: {comparison['statistics'].get('mismatch_percentage', 0):.1f}%",
                    "",
                ]
            )

        # Language agreement
        if comparison["language_agreement"]:
            report_lines.extend(
                [
                    "Languages with Good Agreement:",
                    "  (GitHub primary language matched our detection)",
                ]
            )
            for lang, count in sorted(
                comparison["language_agreement"].items(), key=lambda x: x[1], reverse=True
            ):
                report_lines.append(f"  {lang}: {count} repos")
            report_lines.append("")

        # Language gaps
        if comparison["language_gaps"]:
            report_lines.extend(
                [
                    "Language Detection Gaps:",
                    "  (GitHub detected but we missed as primary)",
                ]
            )
            for lang, count in sorted(
                comparison["language_gaps"].items(), key=lambda x: x[1], reverse=True
            ):
                report_lines.append(f"  {lang}: {count} repos")
            report_lines.append("")

        # Sample mismatches
        if comparison["mismatches"]:
            report_lines.extend(
                [
                    "Sample Mismatches (first 10):",
                ]
            )
            for mismatch in comparison["mismatches"][:10]:
                report_lines.append(f"  Repository: {mismatch['repo']}")
                report_lines.append(f"    GitHub primary: {mismatch['github_primary']}")
                report_lines.append(f"    Our primary: {mismatch['local_primary']}")
                report_lines.append(
                    f"    GitHub languages: {', '.join(mismatch.get('github_languages', []))}"
                )
                report_lines.append(f"    Our types: {', '.join(mismatch.get('local_types', []))}")
                report_lines.append("")

        report_lines.append("=" * 80)
        return "\n".join(report_lines)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Compare GitHub language detection with local project type detection"
    )
    parser.add_argument(
        "--org",
        required=True,
        help="GitHub organization name (e.g., onap)",
    )
    parser.add_argument(
        "--github-token",
        help="GitHub personal access token (or set GITHUB_TOKEN env var)",
    )
    parser.add_argument(
        "--repos-path",
        type=Path,
        help="Path to directory containing cloned repositories",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output file for detailed JSON comparison (default: stdout)",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level",
    )

    args = parser.parse_args()

    # Setup logging
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    logger = logging.getLogger(__name__)

    # Get GitHub token
    github_token = args.github_token or os.environ.get("GITHUB_TOKEN")
    if not github_token:
        logger.error("GitHub token required. Use --github-token or set GITHUB_TOKEN env var")
        return 1

    try:
        # Fetch GitHub data
        logger.info(f"Fetching GitHub language data for organization: {args.org}")
        gh_analyzer = GitHubLanguageAnalyzer(github_token)
        github_data = gh_analyzer.analyze_organization(args.org)
        gh_analyzer.close()

        logger.info(f"Fetched data for {len(github_data)} repositories from GitHub")

        # Analyze local repositories if path provided
        local_data = {}
        if args.repos_path:
            logger.info(f"Analyzing local repositories in: {args.repos_path}")
            local_analyzer = LocalProjectTypeAnalyzer()
            repo_names = list(github_data)
            local_data = local_analyzer.analyze_repositories(args.repos_path, repo_names)
            logger.info(f"Analyzed {len(local_data)} local repositories")
        else:
            logger.warning("No --repos-path provided, skipping local analysis")

        # Compare
        logger.info("Comparing GitHub and local detection results")
        comparator = LanguageComparisonAnalyzer()
        comparison = comparator.compare_repositories(github_data, local_data)

        # Generate report
        report = comparator.generate_report(comparison)
        print("\n" + report)

        # Save detailed JSON if requested
        if args.output:
            output_data = {
                "github_data": github_data,
                "local_data": local_data,
                "comparison": comparison,
            }
            with open(args.output, "w") as f:
                json.dump(output_data, f, indent=2)
            logger.info(f"Detailed comparison saved to: {args.output}")

        return 0

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
