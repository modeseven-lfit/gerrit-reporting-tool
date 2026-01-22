# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""
Integration test fixtures with realistic data structures.

This module provides fixtures that match the ACTUAL data schema used by the
reporting tool, not simplified test data. These fixtures are used to validate
that the RenderContext correctly extracts data from real report JSON.
"""

from datetime import datetime, timedelta
from typing import Any

import pytest


@pytest.fixture
def realistic_report_data() -> dict[str, Any]:
    """
    Realistic report data matching actual JSON schema.

    This fixture represents the actual structure produced by the data aggregation
    pipeline, including:
    - Time-windowed metrics (commit_counts, loc_stats, etc. as dicts)
    - Nested data structures (jenkins.jobs, features, etc.)
    - Actual field names used in production

    This is the "ground truth" for what RenderContext should handle.
    """
    now = datetime.now()

    return {
        "schema_version": "1.2.0",
        "generated_at": now.isoformat(),
        "project": "test-project",
        # Repositories with ACTUAL schema (not simplified)
        "repositories": [
            {
                "gerrit_project": "project/repo1",
                "gerrit_host": "gerrit.example.com",
                "gerrit_url": "https://gerrit.example.com/project/repo1",
                "local_path": "/tmp/repo1",
                "last_commit_timestamp": (now - timedelta(days=5)).isoformat(),
                "days_since_last_commit": 5,
                "activity_status": "current",
                "has_any_commits": True,
                "total_commits_ever": 1250,
                "state": "ACTIVE",
                # Time-windowed commit counts
                "commit_counts": {
                    "last_30": 45,
                    "last_90": 120,
                    "last_365": 450,
                    "last_3_years": 1000,
                },
                # Time-windowed LOC stats
                "loc_stats": {
                    "last_30": {"added": 5000, "removed": 2000, "net": 3000},
                    "last_90": {"added": 12000, "removed": 5000, "net": 7000},
                    "last_365": {"added": 50000, "removed": 20000, "net": 30000},
                    "last_3_years": {"added": 150000, "removed": 60000, "net": 90000},
                },
                # Time-windowed unique contributors
                "unique_contributors": {
                    "last_30": 12,
                    "last_90": 18,
                    "last_365": 35,
                    "last_3_years": 50,
                },
                # Features detection
                "features": {
                    "has_ci": True,
                    "has_gitreview": True,
                    "has_dependabot": False,
                    "has_pre_commit": True,
                },
                # Jenkins jobs (nested under jenkins key)
                "jenkins": {
                    "jobs": [
                        {
                            "name": "repo1-verify",
                            "status": "SUCCESS",
                            "color": "blue",
                            "url": "https://jenkins.example.com/job/repo1-verify",
                        },
                        {
                            "name": "repo1-merge",
                            "status": "SUCCESS",
                            "color": "blue",
                            "url": "https://jenkins.example.com/job/repo1-merge",
                        },
                    ]
                },
                # Authors list
                "authors": [
                    {
                        "name": "Alice Developer",
                        "email": "alice@example.com",
                        "commits": 150,
                    },
                    {
                        "name": "Bob Contributor",
                        "email": "bob@example.com",
                        "commits": 80,
                    },
                ],
            },
            {
                "gerrit_project": "project/repo2",
                "gerrit_host": "gerrit.example.com",
                "gerrit_url": "https://gerrit.example.com/project/repo2",
                "local_path": "/tmp/repo2",
                "last_commit_timestamp": (now - timedelta(days=400)).isoformat(),
                "days_since_last_commit": 400,
                "activity_status": "inactive",
                "has_any_commits": True,
                "total_commits_ever": 500,
                "state": "READ_ONLY",
                "commit_counts": {
                    "last_30": 0,
                    "last_90": 0,
                    "last_365": 0,
                    "last_3_years": 5,
                },
                "loc_stats": {
                    "last_30": {"added": 0, "removed": 0, "net": 0},
                    "last_90": {"added": 0, "removed": 0, "net": 0},
                    "last_365": {"added": 0, "removed": 0, "net": 0},
                    "last_3_years": {"added": 1000, "removed": 500, "net": 500},
                },
                "unique_contributors": {
                    "last_30": 0,
                    "last_90": 0,
                    "last_365": 0,
                    "last_3_years": 3,
                },
                "features": {
                    "has_ci": False,
                    "has_gitreview": True,
                },
                "jenkins": {"jobs": []},
                "authors": [],
            },
        ],
        # Authors aggregated across all repos
        "authors": {
            "alice@example.com": {
                "name": "Alice Developer",
                "email": "alice@example.com",
                "username": "alice",
                "domain": "example.com",
                "total_commits": 150,
                "repositories": ["project/repo1"],
            },
            "bob@example.com": {
                "name": "Bob Contributor",
                "email": "bob@example.com",
                "username": "bob",
                "domain": "example.com",
                "total_commits": 80,
                "repositories": ["project/repo1"],
            },
        },
        # Organizations aggregated from author domains
        "organizations": {
            "example.com": {
                "domain": "example.com",
                "contributors": ["alice@example.com", "bob@example.com"],
                "total_commits": 230,
            }
        },
        # Summaries section with actual structure
        "summaries": {
            "reporting_period": {
                "start": (now - timedelta(days=365)).isoformat(),
                "end": now.isoformat(),
                "window_name": "last_365",
            },
            "counts": {
                "total_repositories": 2,
                "current_repositories": 1,
                "active_repositories": 0,
                "inactive_repositories": 1,
                "no_commit_repositories": 0,
                "total_commits": 1750,
                "total_lines_added": 151000,
                "total_lines_removed": 60500,
                "total_authors": 2,
                "total_organizations": 1,
            },
            "activity_status_distribution": {
                "current": 1,
                "active": 0,
                "inactive": 1,
            },
            # Repository lists
            "all_repositories": [
                {
                    "gerrit_project": "project/repo1",
                    "total_commits_ever": 1250,
                    "activity_status": "current",
                    "days_since_last_commit": 5,
                    "state": "ACTIVE",
                    "commit_counts": {
                        "last_30": 45,
                        "last_90": 120,
                        "last_365": 450,
                        "last_3_years": 1000,
                    },
                    "unique_contributors": {
                        "last_30": 12,
                        "last_90": 18,
                        "last_365": 35,
                        "last_3_years": 50,
                    },
                    "jenkins": {
                        "jobs": [
                            {"name": "repo1-verify", "status": "SUCCESS"},
                            {"name": "repo1-merge", "status": "SUCCESS"},
                        ]
                    },
                },
                {
                    "gerrit_project": "project/repo2",
                    "total_commits_ever": 500,
                    "activity_status": "inactive",
                    "days_since_last_commit": 400,
                    "state": "READ_ONLY",
                    "commit_counts": {
                        "last_30": 0,
                        "last_90": 0,
                        "last_365": 0,
                        "last_3_years": 5,
                    },
                    "unique_contributors": {
                        "last_30": 0,
                        "last_90": 0,
                        "last_365": 0,
                        "last_3_years": 3,
                    },
                    "jenkins": {"jobs": []},
                },
            ],
            "no_commit_repositories": [],
            # Top contributors with time-windowed metrics
            "top_contributors_commits": [
                {
                    "name": "Alice Developer",
                    "email": "alice@example.com",
                    "username": "alice",
                    "domain": "example.com",
                    "commits": {
                        "last_30": 25,
                        "last_90": 60,
                        "last_365": 120,
                        "last_3_years": 150,
                    },
                    "lines_added": {
                        "last_30": 3000,
                        "last_90": 7000,
                        "last_365": 30000,
                        "last_3_years": 90000,
                    },
                    "lines_removed": {
                        "last_30": 1200,
                        "last_90": 2800,
                        "last_365": 12000,
                        "last_3_years": 36000,
                    },
                    "lines_net": {
                        "last_30": 1800,
                        "last_90": 4200,
                        "last_365": 18000,
                        "last_3_years": 54000,
                    },
                    "repositories_count": {
                        "last_30": 1,
                        "last_90": 1,
                        "last_365": 1,
                        "last_3_years": 1,
                    },
                },
                {
                    "name": "Bob Contributor",
                    "email": "bob@example.com",
                    "username": "bob",
                    "domain": "example.com",
                    "commits": {
                        "last_30": 20,
                        "last_90": 60,
                        "last_365": 330,
                        "last_3_years": 80,
                    },
                    "lines_added": {
                        "last_30": 2000,
                        "last_90": 5000,
                        "last_365": 20000,
                        "last_3_years": 60000,
                    },
                    "lines_removed": {
                        "last_30": 800,
                        "last_90": 2200,
                        "last_365": 8000,
                        "last_3_years": 24000,
                    },
                    "lines_net": {
                        "last_30": 1200,
                        "last_90": 2800,
                        "last_365": 12000,
                        "last_3_years": 36000,
                    },
                    "repositories_count": {
                        "last_30": 1,
                        "last_90": 1,
                        "last_365": 1,
                        "last_3_years": 1,
                    },
                },
            ],
            # Top contributors by LOC
            "top_contributors_loc": [
                {
                    "name": "Alice Developer",
                    "email": "alice@example.com",
                    "username": "alice",
                    "domain": "example.com",
                    "commits": {
                        "last_30": 25,
                        "last_90": 60,
                        "last_365": 120,
                        "last_3_years": 150,
                    },
                    "lines_added": {
                        "last_30": 3000,
                        "last_90": 7000,
                        "last_365": 30000,
                        "last_3_years": 90000,
                    },
                    "lines_removed": {
                        "last_30": 1200,
                        "last_90": 2800,
                        "last_365": 12000,
                        "last_3_years": 36000,
                    },
                    "lines_net": {
                        "last_30": 1800,
                        "last_90": 4200,
                        "last_365": 18000,
                        "last_3_years": 54000,
                    },
                    "repositories_count": {
                        "last_30": 1,
                        "last_90": 1,
                        "last_365": 1,
                        "last_3_years": 1,
                    },
                },
            ],
            # Top organizations with time-windowed metrics
            "top_organizations": [
                {
                    "domain": "example.com",
                    "contributor_count": 2,
                    "commits": {
                        "last_30": 45,
                        "last_90": 120,
                        "last_365": 450,
                        "last_3_years": 230,
                    },
                    "lines_added": {
                        "last_30": 5000,
                        "last_90": 12000,
                        "last_365": 50000,
                        "last_3_years": 150000,
                    },
                    "lines_removed": {
                        "last_30": 2000,
                        "last_90": 5000,
                        "last_365": 20000,
                        "last_3_years": 60000,
                    },
                    "lines_net": {
                        "last_30": 3000,
                        "last_90": 7000,
                        "last_365": 30000,
                        "last_3_years": 90000,
                    },
                    "repositories_count": {
                        "last_30": 1,
                        "last_90": 1,
                        "last_365": 1,
                        "last_3_years": 2,
                    },
                },
            ],
        },
        # Orphaned jobs
        "orphaned_jenkins_jobs": {
            "total_orphaned_jobs": 2,
            "jobs": {
                "old-project-verify": {
                    "project_name": "old-project",
                    "state": "READ_ONLY",
                    "score": 95,
                },
                "archived-project-merge": {
                    "project_name": "archived-project",
                    "state": "ARCHIVED",
                    "score": 88,
                },
            },
            "by_state": {
                "READ_ONLY": 1,
                "ARCHIVED": 1,
            },
        },
        # Time windows
        "time_windows": [
            {
                "name": "last_30",
                "days": 30,
                "start_date": (now - timedelta(days=30)).strftime("%Y-%m-%d"),
                "end_date": now.strftime("%Y-%m-%d"),
                "commits": 45,
                "contributors": 12,
                "lines_added": 5000,
                "lines_removed": 2000,
                "net_lines": 3000,
            },
            {
                "name": "last_90",
                "days": 90,
                "start_date": (now - timedelta(days=90)).strftime("%Y-%m-%d"),
                "end_date": now.strftime("%Y-%m-%d"),
                "commits": 120,
                "contributors": 18,
                "lines_added": 12000,
                "lines_removed": 5000,
                "net_lines": 7000,
            },
        ],
    }


@pytest.fixture
def minimal_config() -> dict[str, Any]:
    """Minimal valid configuration."""
    return {
        "project": "test-project",
        "output": {
            "theme": "default",
            "table_of_contents": True,
            "top_contributors_limit": 20,
            "top_organizations_limit": 20,
        },
    }


@pytest.fixture
def full_config() -> dict[str, Any]:
    """Full configuration with all options."""
    return {
        "project": {
            "name": "Test Project",
            "description": "A test project",
        },
        "output": {
            "theme": "default",
            "table_of_contents": True,
            "top_contributors_limit": 10,
            "top_organizations_limit": 10,
            "include_summary": True,
            "include_repositories": True,
            "include_contributors": True,
            "include_organizations": True,
            "include_features": True,
            "include_workflows": True,
            "include_orphaned_jobs": True,
            "include_time_windows": True,
        },
        "render": {
            "theme": "default",
            "table_of_contents": True,
        },
    }
