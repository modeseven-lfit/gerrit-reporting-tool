<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Artifact Archival Setup Guide

This guide explains how to set up and use the automated artifact archival feature that copies report outputs to the `project-reporting-artifacts` repository for long-term storage and analytics.

---

## 📋 Overview

The reporting tool now includes an automated archival system that copies all report artifacts to a separate GitHub repository (`modeseven-lfit/project-reporting-artifacts`) after each production run. This enables:

- **Long-term storage** of historical report data
- **Trend analysis** across time periods
- **Data preservation** beyond GitHub Actions artifact retention limits (90 days)
- **Analytics capabilities** on report changes over time

### How It Works

1. **Scheduled Runs**: Daily at 7:00 AM UTC (CRON schedule)
   - Generates reports for all configured projects
   - Automatically copies artifacts to `project-reporting-artifacts` repository
   - Creates timestamped folders: `data/artifacts/YYYY-MM-DD/`

2. **Manual Runs**: Via workflow dispatch
   - Generates reports for all configured projects
   - Only copies artifacts if the date folder doesn't already exist
   - Prevents overwriting existing data from transient error recovery

---

## 🔧 Setup Instructions

### Prerequisites

1. Access to the `modeseven-lfit/project-reporting-artifacts` repository
2. Permission to create GitHub secrets in the `reporting-tool` repository
3. A GitHub Personal Access Token (PAT) with appropriate permissions

### Step 1: Create GitHub Personal Access Token

Create a PAT with the following permissions for the `project-reporting-artifacts` repository:

**Classic Token:**

- `repo` (Full control of private repositories)
  - `repo:status` - Access commit status
  - `repo_deployment` - Access deployment status
  - `public_repo` - Access public repositories
  - `repo:invite` - Access repository invitations

**Fine-Grained Token (Recommended):**

- **Repository access**: `modeseven-lfit/project-reporting-artifacts` only
- **Permissions**:
  - Contents: `Read and write`
  - Metadata: `Read-only`

**Token creation steps:**

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Generate new token" (classic) or "Generate new token" (fine-grained)
3. Name: `Gerrit Reports Archival Token`
4. Expiration: Set appropriate expiration (e.g., 90 days, 1 year)
5. Select scopes/permissions as listed above
6. Click "Generate token"
7. **Copy the token immediately** (you won't be able to see it again)

### Step 2: Add Secret to Repository

Add the PAT as a repository secret:

1. Navigate to the `reporting-tool` repository
2. Go to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `GERRIT_REPORTS_PAT_TOKEN`
5. Value: Paste the PAT token created in Step 1
6. Click "Add secret"

### Step 3: Verify Workflow Configuration

The workflow is already configured in `.github/workflows/reporting-production.yaml`. Verify the job exists:

```yaml
copy-to-artifacts-repo:
  name: "Transfer/Copy Artifacts"
  needs: [validate-secrets, build-matrix, analyze]
  if: |
    always() &&
    needs.validate-secrets.result == 'success' &&
    (github.event_name == 'schedule' || github.event_name == 'workflow_dispatch')
  runs-on: ubuntu-latest
  # ... rest of configuration
```

### Step 4: Test the Setup

Test with a manual workflow dispatch:

1. Go to Actions → "📊 Production Reports"
2. Click "Run workflow"
3. Select branch: `main`
4. Click "Run workflow"
5. Monitor the workflow run
6. Check the `copy-to-artifacts-repo` job for success
7. Verify artifacts in `project-reporting-artifacts` repository

---

## 📂 Output Structure

Artifacts are organized in the `project-reporting-artifacts` repository as follows:

```text
project-reporting-artifacts/
└── data/
    └── artifacts/
        ├── 2025-01-20/
        │   ├── README.md                    # Metadata about this date's reports
        │   ├── reports-ONAP/
        │   │   ├── report.html              # HTML report
        │   │   ├── report.md                # Markdown report
        │   │   ├── report_raw.json          # Raw analysis data
        │   │   ├── config_resolved.json     # Resolved configuration
        │   │   └── metadata.json            # Report metadata
        │   ├── reports-ProjectName/
        │   │   └── ...
        │   └── reports-AnotherProject/
        │       └── ...
        ├── 2025-01-21/
        │   └── ...
        └── 2025-01-22/
            └── ...
```

### README.md Contents

Each date folder includes a `README.md` with:

- Generation timestamp
- Number of projects processed
- Total file count
- Workflow run ID and trigger type
- List of all projects and file counts

---

## 🔄 Workflow Behavior

### Scheduled (CRON) Runs

**Trigger**: Daily at 7:00 AM UTC

**Behavior**:

- Generates reports for all projects
- Copies artifacts to `data/artifacts/<DATE>/`
- **Overwrites** existing folder if it exists (unusual but handles edge cases)
- Creates commit with descriptive message
- Pushes to `main` branch of `project-reporting-artifacts`

### Manual Dispatch Runs

**Trigger**: Manual workflow dispatch via GitHub UI

**Behavior**:

- Generates reports for all projects
- Checks if `data/artifacts/<DATE>/` already exists
- **If folder exists**: Skips upload, logs warning, exits with success
- **If folder doesn't exist**: Proceeds with normal upload
- Prevents overwriting data when re-running failed workflows

**Use case**: Re-running reports that failed due to transient errors (e.g., Gerrit server issues) without overwriting already-archived data.

---

## 🔍 Monitoring and Verification

### Check Workflow Status

1. Go to Actions → "📊 Production Reports"
2. Click on a workflow run
3. Expand "Transfer/Copy Artifacts" job
4. Review the output logs

### Verify Artifacts in Target Repository

1. Navigate to `https://github.com/modeseven-lfit/project-reporting-artifacts`
2. Browse to `data/artifacts/<DATE>/`
3. Verify folders exist for each project
4. Check the `README.md` for summary information

### Job Summary

The workflow provides a job summary with:

- Date folder created
- Target repository link
- Job status (success/failure)
- Direct link to artifacts in target repository

---

## 🐛 Troubleshooting

### Secret Not Found

**Error**: `GERRIT_REPORTS_PAT_TOKEN secret not found`

**Solution**:

1. Verify secret exists in repository settings
2. Check secret name matches exactly: `GERRIT_REPORTS_PAT_TOKEN`
3. Ensure you have admin access to add secrets

### Authentication Failed

**Error**: `Failed to clone repository` or `Permission denied`

**Solution**:

1. Verify PAT token has correct permissions (see Step 1)
2. Check token hasn't expired
3. Regenerate token if necessary
4. Update secret with new token

### Target Folder Already Exists

**Warning**: `Target directory already exists: data/artifacts/YYYY-MM-DD`

**For Manual Runs**: This is expected behavior. The script skips upload to prevent overwriting.

**For Scheduled Runs**: This is unusual but handled. The script will overwrite.

**To Force Update**:

1. Manually delete the folder in `project-reporting-artifacts` repository
2. Re-run the workflow

### No Files Copied

**Error**: `No files were copied from artifacts`

**Solution**:

1. Check that previous jobs (`analyze`) completed successfully
2. Verify artifacts were uploaded in the `analyze` job
3. Check artifact retention period hasn't expired
4. Review workflow logs for artifact download failures

### Git Push Failed

**Error**: `Failed to push changes to remote repository`

**Solutions**:

1. Check PAT token has `Contents: Write` permission
2. Verify target repository exists and is accessible
3. Check for branch protection rules that might block pushes
4. Ensure token hasn't expired

### Rate Limit Exceeded

**Error**: API rate limit exceeded during git operations

**Solution**:

1. Wait for rate limit to reset (typically 1 hour)
2. Consider using a different PAT if multiple workflows use the same token
3. Check GitHub API rate limit status

---

## 🔒 Security Considerations

### Token Security

- **Never commit tokens to the repository**
- Store tokens only in GitHub Secrets
- Use fine-grained tokens with minimal required permissions
- Set appropriate expiration dates
- Rotate tokens regularly (recommended: every 90 days)
- Audit token usage periodically

### Access Control

- Limit repository access to necessary personnel
- Use branch protection rules in `project-reporting-artifacts` repository
- Review commit history regularly
- Enable audit logging for sensitive operations

### Data Privacy

- Ensure report data doesn't contain sensitive information
- Review artifacts before archival if necessary
- Implement data retention policies
- Consider privacy implications of long-term storage

---

## 📊 Analytics Use Cases

The archived artifacts enable various analytics scenarios:

### Trend Analysis

Track changes over time:

- Number of contributors per project
- Commit activity patterns
- Migration progress (if tracking Gerrit → GitHub migrations)
- Repository growth/decline

### Historical Comparison

Compare reports across dates:

- Week-over-week changes
- Month-over-month trends
- Year-over-year growth
- Seasonal patterns

### Meta-Reporting

Generate reports about reports:

- Average report generation time
- Success/failure rates
- Project activity heatmaps
- Contributor retention metrics

### Data Science

Machine learning and statistical analysis:

- Predict future activity
- Identify anomalies
- Cluster similar projects
- Forecast resource needs

---

## 🔄 Maintenance

### Regular Tasks

**Weekly**:

- Review workflow success rates
- Check storage usage in `project-reporting-artifacts` repository

**Monthly**:

- Verify token is valid and not expiring soon
- Review archived data structure
- Check for any failed uploads

**Quarterly**:

- Rotate PAT token (if policy requires)
- Review and optimize storage usage
- Audit access to archived data
- Update documentation if needed

### Data Retention

Consider implementing a data retention policy:

**Recommended Retention**:

- Daily reports: Keep last 90 days
- Weekly summaries: Keep last 1 year
- Monthly summaries: Keep indefinitely

**Implementation**:

1. Create a separate workflow in `project-reporting-artifacts` repository
2. Run monthly to clean up old daily reports
3. Generate and preserve weekly/monthly summaries
4. Archive to long-term storage if needed

---

## 🚀 Future Enhancements

Potential improvements to the archival system:

### Compression

- Compress JSON files before archival
- Use Git LFS for large files
- Implement incremental backups

### Metadata

- Add more detailed metadata
- Include workflow execution metrics
- Track artifact sizes

### Notifications

- Send alerts on archival failures
- Weekly summary emails
- Slack/Discord integration

### Analytics Dashboard

- Build web dashboard in `project-reporting-artifacts` repo
- Visualize trends over time
- Interactive data exploration
- Export capabilities

---

## 📚 Related Documentation

- [GitHub Pages Setup](./GITHUB_PAGES_SETUP.md)
- [CI/CD Integration](./CI_CD_INTEGRATION.md)
- [Scripts Documentation](../.github/scripts/README.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

---

## 🤝 Contributing

To improve the archival system:

1. Test changes in a fork first
2. Update documentation
3. Consider backward compatibility
4. Add error handling
5. Update tests if applicable

---

## 📞 Support

For issues or questions:

1. Check this documentation first
2. Review [Troubleshooting Guide](./TROUBLESHOOTING.md)
3. Check workflow run logs
4. Review script output in GitHub Actions
5. Contact Linux Foundation Release Engineering team

---

**Last Updated**: 2025-01-20
**Maintained By**: Linux Foundation Release Engineering
**Version**: 1.0
