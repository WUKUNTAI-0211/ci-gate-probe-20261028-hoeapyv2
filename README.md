# PR Gate neutral probe

This is an isolated GitHub experiment for the neutral-retirement concern. It mirrors check creation/selection/retirement from the proposed publisher; it is not the full router CI and does not prove its artifact or authorization paths. No models or containers run. No Mergify setup is needed: this tests GitHub branch protection directly.

## Create a NEW disposable repository

Run these commands only inside this directory. Choose a new repository name, not semantic-router. These commands create a remote repository and configure protection; run them before starting the experiment.

```bash
PROBE_REPO=WUKUNTAI-0211/ci-gate-probe-test

git init -b main
git add .
git commit -s -m "Add isolated PR Gate probe"
gh repo create "$PROBE_REPO" --public --source=. --remote=origin --push

gh api --method PUT "repos/$PROBE_REPO/branches/main/protection" --input protection.json

git switch -c probe
printf 'probe\n' > probe.txt
git add probe.txt
git commit -s -m "Trigger PR Gate probe"
git push -u origin probe
gh pr create --repo "$PROBE_REPO" --base main --head probe --title "Probe required PR Gate selection" --body "Disposable test; do not merge before recording all phases."
```

Protection requires only `PR Gate` from GitHub Actions and enforces the rule for administrators. Check that the new repo has no bypass or additional rules. The workflow_run publisher must already be on default branch main before opening the PR. The public repo permits branch protection with a free account; use a private repo only if your plan supports its protection.

## Three phases, no actual merge required

1. Wait for the first **Gate Probe PR** run AND its **Gate Probe Publisher** run to finish. The first run creates a pending C1, representing expensive checks awaiting authorization. Record `bash snapshot.sh "$PROBE_REPO" 1`. The required gate must block merging.
2. In Actions, select that original **Gate Probe PR** run and use **Re-run all jobs** (or `gh run rerun RUN_ID --repo "$PROBE_REPO"`). Do not rerun the publisher. During attempt 2, after its in_progress publisher finishes, there is a 180-second observation window. Run snapshot again. It must show the old C1 neutral and new C2 pending; merging must remain blocked. If the publisher did not finish during the window, the pending-phase observation is inconclusive; lengthen the sleep in a fresh probe and try again.
3. Wait for attempt 2 and its completed publisher. The new gate must be failure and merging must remain blocked. Re-run the same original PR run once more for attempt 3. During its observation window the new gate must block. After it and its publisher finish, the new gate becomes success and the required gate should allow merging.

The attempt number belongs to one workflow run; pushing another commit creates a new run and does not reproduce these phases. Capture snapshots in all phases. Do not use admin bypass or merge overrides as evidence. No actual merge is necessary: inspect the PR's required-check messages and enabled/disabled merge controls alongside the API snapshots. `mergeable: MERGEABLE` alone only means no Git conflict. Nonrequired `Probe execution` deliberately fails in attempt 2, so do not use its status alone to judge the required gate.

| Phase | New gate | Old gate | Expected required-gate decision |
| --- | --- | --- | --- |
| Attempt 1 complete | pending | none | block |
| Attempt 2 running | pending | neutral | block |
| Attempt 2 complete | failure | neutral | block |
| Attempt 3 running | pending | neutral/failure | block |
| Attempt 3 complete | success | neutral/failure | allow |

If GitHub permits merging during a pending/failure phase, the fail-open concern is reproduced. If success stays blocked, capture the old check/suite that causes a persistent block. If all phases behave correctly, the concern was not reproduced in this configuration; that is evidence for this configuration, not proof for every suite layout.

References:
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging
- https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference
