#!/usr/bin/env bash
set -euo pipefail
probe_repo=${1:?Usage: bash snapshot.sh OWNER/ci-gate-probe PR_NUMBER}
probe_pr=${2:?PR number required}
probe_head=$(gh pr view "$probe_pr" --repo "$probe_repo" --json headRefOid --jq .headRefOid)
gh api "repos/$probe_repo/branches/main/protection" --jq '{required:.required_status_checks,enforce_admins:.enforce_admins.enabled}'
for filter in all latest; do
  echo "PR Gate filter=$filter"
  gh api "repos/$probe_repo/commits/$probe_head/check-runs?check_name=PR%20Gate&filter=$filter&per_page=100" --jq '.check_runs[] | {id,suite:.check_suite.id,status,conclusion,external_id,completed_at}'
done
gh pr view "$probe_pr" --repo "$probe_repo" --json mergeable,mergeStateStatus,statusCheckRollup --jq '{mergeable,mergeStateStatus,gates:[.statusCheckRollup[] | select(.name == "PR Gate") | {name,status,conclusion,detailsUrl}]}'
# This command is expected to return nonzero while required checks are pending/failing.
gh pr checks "$probe_pr" --repo "$probe_repo" --required
