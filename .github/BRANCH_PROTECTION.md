# GitHub Branch Protection Setup for Renovate

This document provides step-by-step instructions for configuring branch protection rules to work effectively with Renovate dependency update pull requests.

## Overview

Branch protection rules ensure code quality and security by enforcing status checks and review requirements before merging pull requests. When combined with Renovate, they help maintain a controlled and auditable dependency update process.

## Prerequisites

- Administrator access to the GitHub repository
- The Renovate workflow is already configured and running (see `.github/workflows/renovate-container-check.yml`)

## Setup Steps

### 1. Navigate to Branch Protection Settings

1. Go to your repository on GitHub
2. Click **Settings** (top navigation)
3. In the left sidebar, click **Branches**
4. Under "Branch protection rules", click **Add rule**

### 2. Configure the Protection Rule

#### Step 2.1: Specify Which Branches to Protect

- **Branch name pattern**: Enter `main` (or your default branch name)
  - This rule will apply to this branch and any matching branches
  - You can use wildcards like `release/*` for multiple branches

#### Step 2.2: Require Status Checks to Pass Before Merging

1. Enable **Require status checks to pass before merging**
2. Enable **Require branches to be up to date before merging**
3. In the search box, add required status checks:
   - If you have CI/CD workflows, add them here
   - For Renovate-only repositories, this may be optional
   - Common checks: `build`, `test`, `lint`

#### Step 2.3: Require Pull Request Reviews

1. Enable **Require a pull request before merging**
2. Set **Require approvals**: Choose number of reviewers (recommend: 1 minimum)
3. **Optional**: Enable **Dismiss stale pull request approvals when new commits are pushed**
   - This ensures Renovate PRs are re-reviewed after updates
4. **Optional**: Enable **Require code review from code owners**
   - If you have a `CODEOWNERS` file

#### Step 2.4: Allow Auto-Merge

1. **Optional**: Enable **Allow auto-merge**
   - This allows the "squash and merge" or "rebase and merge" options
   - Useful for controlled merging of Renovate PRs
   - Note: Renovate cannot auto-merge by default (unless explicitly configured)

#### Step 2.5: Additional Security Options

1. **Optional**: Enable **Restrict who can push to matching branches**
   - Limit push access to admins or specific users
   - Does not apply to PRs (only direct pushes)

2. **Optional**: Enable **Require status checks to pass before merging**
   - Ensures code quality before any merge

3. **Optional**: Enable **Include administrators**
   - Enforce the same rules for repository administrators
   - Recommended for consistency

### 3. Configure Renovate to Work with Branch Protection

Renovate respects all branch protection rules automatically. To ensure smooth operation:

#### 3.1: Ensure Renovate Has Appropriate Permissions

Your GitHub Actions workflow needs:
- `contents: write` - To create and update PRs
- `pull-requests: write` - To manage PR metadata
- `issues: write` - To log and report updates

These are already configured in `.github/workflows/renovate-container-check.yml`.

#### 3.2: Optional - Configure Renovate PR Behavior

Edit `.github/renovate.json` to customize:

```json
{
  "assignees": ["@you"],
  "labels": ["dependencies", "renovate"],
  "reviewers": ["@you"],
  "assigneesSampleSize": 1,
  "ignoreDeps": [],
  "automerge": false
}
```

## Workflow: How Renovate PRs Work with Branch Protection

1. **Renovate runs nightly** at 2 AM UTC (configured in workflow)
2. **Creates pull requests** for detected dependency updates
3. **Status checks run** automatically on the PR
4. **Review required** before merging (if enabled in branch protection)
5. **Merge manually** when satisfied with the changes

## Example Branch Protection Configuration

Here's a recommended minimal configuration:

- ✅ Require a pull request before merging (1 approval)
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Allow auto-merge (for convenience)
- ✅ Include administrators (for consistency)

## Troubleshooting

### "Renovate bot cannot merge PRs"

**Solution**: Renovate is configured not to auto-merge (as requested). This is by design - all PRs require manual review and merge.

### "Status checks are failing"

**Solution**: Review the failing check in the PR details. Common causes:
- Container build failures
- Test failures
- Linting issues

Check the Renovate PR for details and fix the issues before merging.

### "Renovate PRs are waiting for review"

**Solution**: This is expected behavior with branch protection enabled. Review the PR and approve/merge it manually.

### "Renovate is not creating any PRs"

**Solution**: 
1. Check that the workflow has run (go to **Actions** tab)
2. Review workflow logs for errors
3. Verify `renovate.json` configuration is valid (JSON syntax)
4. Ensure Renovate has permissions to access the repository

## Best Practices

1. **Review Renovate PRs carefully** - Always check changelogs for major updates
2. **Test container builds** - Especially for base image updates
3. **Group related updates** - Renovate automatically groups updates by type
4. **Keep Renovate updated** - The workflow uses a pinned version, update it periodically
5. **Monitor PR creation rate** - Adjust `prConcurrentLimit` in `renovate.json` if too many PRs are created
6. **Use labels** - Add labels to Renovate PRs for better organization and filtering

## Additional Resources

- [Renovate Documentation](https://docs.renovatebot.com/)
- [GitHub Branch Protection Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
