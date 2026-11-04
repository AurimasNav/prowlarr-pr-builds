# prowlarr-pr-builds

Unofficial test builds of open [Prowlarr](https://github.com/Prowlarr/Prowlarr) pull requests,
used to try a PR in a home test instance before it is released. Not affiliated with the
Prowlarr team; don't use these images for anything you care about.

The workflow **Build Prowlarr PR image** (run by hand) merges one PR into a Prowlarr branch
(default `develop`), builds it with Prowlarr's own `build.sh` for `linux-musl-x64`, runs the
PR's indexer tests, and pushes `ghcr.io/aurimasnav/prowlarr-pr-builds:pr<number>-<pr sha>-<branch>-<branch sha>`.
The image is the [linuxserver.io Prowlarr image](https://github.com/linuxserver/docker-prowlarr)
with Prowlarr swapped for that build. Before pushing, the image is started once and must report the expected version and list the indexer the PR adds.

The PR's code runs in a job with a read-only token; only the final job, which runs no PR
code, can push the image.

Prowlarr is licensed under GPL-3.0. The source of every image is the Prowlarr branch and PR
commit named in its labels (`io.github.prowlarr.base-revision`, `org.opencontainers.image.revision`).

## Testing proposed fixes

`patches/<name>.patch` holds a fix proposed to the PR author; run the workflow with `patch: <name>`
to build the PR with that patch applied on top (the image tag ends in `-<name>-r<run>`).

Patches whose names end in `-test-only` or `-tests-only`, and `pr2765-v2-tests-on-v1`, add tests without
the fix they check. Their runs are meant to fail: the failing tests show that the tests catch the bug.
A red run with one of these patches is not a broken build.

LostFilm (#2765), one patch per fix proposed upstream:

- `pr2765-pr-a-date-parsing`: parses dates without ru-RU culture data.
- `pr2765-pr-b-mirror-session`: reuses the session on the mirror after a geo-block, instead of logging
  in again with the used captcha.
- `pr2765-pr-c-used-captcha`: doesn't resubmit a captcha that was already used, and retries once
  without a rejected one.
- `pr2765-pr-d-email-label`: labels the login field Email.
- `pr2765-pr-e-history`: attaches the search and RSS responses, so History and the indexer stats
  record the query as successful, with the time of the whole query.

Combinations: `pr2765-pr-a-plus-b`, `pr2765-pr-a-b-c`, `pr2765-pr-a-b-c-d`, `pr2765-pr-a-b-c-e` (all but
the Email label, so a test instance keeps its saved login) and `pr2765-pr-a-e` (all five).

Tests only, meant to fail:

- `pr2765-pr-c-tests-only`: the tests from `pr2765-pr-c-used-captcha`.
- `pr2765-pr-e-tests-only`: the tests from `pr2765-pr-e-history`.
- `pr2765-session-test-only`: the mirror-session test from `pr2765-lostfilm-fixes`.
- `pr2765-v2-session-test-only`: the mirror-session tests from `pr2765-lostfilm-fixes-v2`.
- `pr2765-v2-tests-on-v1`: the v2 tests on top of the v1 fix; two of them fail, which shows what v2 adds.

Earlier rounds, replaced by the patches above: `pr2765-lostfilm-fixes` (mirror session and dates) and
`pr2765-lostfilm-fixes-v2`.
