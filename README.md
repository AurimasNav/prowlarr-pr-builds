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

- `pr2765-lostfilm-fixes`: LostFilm (#2765) reuses the session on the mirror after a geo-block
  (no re-login with the used captcha) and parses dates without ru-RU culture data.
- `pr2765-session-test-only`: only the new mirror-session test from `pr2765-lostfilm-fixes`, to show it fails without the fix.
