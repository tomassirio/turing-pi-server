# Homarr dashboard migration & curation

## Context

`services/homerr` is a Helm chart named `homer`, running `b4bz/homer` — a different
project from Homarr entirely. It hasn't kept pace with the cluster:

- Its `templates/configmap.yaml` hardcodes plaintext Jellyfin/Sonarr/Radarr/Lidarr/
  Prowlarr API keys, committed to git.
- It links to Jellyfin and Retroarch, neither of which is a deployed service.
- It's missing tiles for every service added since: Bazarr, Cleanuparr,
  Audiobookshelf, FlareSolverr, Filebrowser-guests, Navidrome, ntfy, Picard, Seerr
  (present but stale), Technitium, Twingate, Wireshark.

The user wants to move to the actively developed Homarr
(`ghcr.io/homarr-labs/homarr`), then re-curate the dashboard against what's
actually deployed today.

Homarr's own docs (`https://homarr.dev/docs/getting-started/installation/helm`)
confirm: `SECRET_ENCRYPTION_KEY` is required, default port `7575`, and board/tile/
widget state lives in Homarr's own database — there is no config-as-code path for
boards. Docker-socket integration is optional and not applicable here (k3s nodes
run containerd, not Docker).

## Goals

1. Replace the Homer chart with a self-authored Homarr chart, following this
   repo's existing conventions (`services/picard` is the closest current
   reference).
2. Stop leaking API keys in git; adopt SOPS for this service's one real secret.
3. Re-curate the dashboard's groups/tiles against the services actually deployed
   today, dropping stale entries and adding missing ones.

## Non-goals

- Rotating the *arr API keys that leaked in the old Homer configmap (they'll stay
  out of git going forward, but rotating already-issued keys is a separate task).
- Building any automation/API tooling to make Homarr board state declarative —
  Homarr has no supported mechanism for this; board curation is a one-time manual
  step done through its UI.
- Docker-socket / container-discovery integration.

## Design

### Chart (`services/homarr`, replacing `services/homerr`)

Self-authored chart modeled on `services/picard`'s structure (StatefulSet,
Service, Ingress, ServiceAccount, HPA stub, `common` chart dependency for
backup/restore) rather than vendoring the upstream OCI chart, to match how every
other service in this repo is built.

- Image: `ghcr.io/homarr-labs/homarr`, tag `latest` (repo convention — every
  other service pins `latest` in `values.yaml` and lets `Chart.yaml`'s
  `appVersion` be informational).
- Service port: `7575` (container), matching Homarr's default.
- Ingress: host `dashboard.localhome.com` (unchanged from Homer), TLS via
  `localhome-tls`, same nginx annotations pattern as other services.
- No docker socket mount.

### Persistence

Homarr's `appdata` holds a SQLite database. SQLite over NFS risks lock
corruption, so `appdata` is a local `emptyDir`, backed up/restored via the
repo's existing `common.backup.sidecar` / `common.restore.initContainer`
templates against `nas-config-pvc`, subPath `homarr` — the same pattern already
used by `picard` and the `*arr` services.

### Secret

`SECRET_ENCRYPTION_KEY` is generated once (`openssl rand -hex 32`) and stored in
`services/homarr/secrets.yaml`, encrypted with the repo's existing SOPS age
recipient (same shape as `services/configarr/secrets.yaml` /
`services/qbittorrent/secrets.yaml`), decrypted at deploy time by the existing
`helm-deploy.yaml` SOPS step, and injected as an env var. This service did not
use SOPS before; it does from now on.

### Removal

`services/homerr` is deleted outright (`git rm -r`) — no dangling Homer
manifests, no plaintext keys left in the working tree. (They remain in git
history; out of scope per Non-goals.)

### Deployment

No entry needed in `config/namespace-overrides.txt` — deploys to the caller's
default namespace, same as `picard`/`radarr`/`sonarr`.

### Board curation (post-deploy, manual/interactive — not part of the chart)

Because Homarr has no config-as-code path:

1. User completes Homarr's first-run onboarding (creates the admin account) —
   Claude does not handle or see the admin password.
2. Claude then drives the already-authenticated Chrome session via
   `claude-in-chrome` to build out the groups/tiles/widgets directly in the UI.

Proposed grouping, built from the actual current ingress hosts (only services
with a real web UI, plus the two game servers per explicit user request):

| Group | Tiles |
|---|---|
| Media | Seerr, Sonarr, Radarr, Lidarr, Bazarr, Audiobookshelf, Navidrome |
| Downloads & Indexing | qBittorrent, Prowlarr, FlareSolverr, Cleanuparr |
| Monitoring | Grafana, Prometheus |
| Files | File Browser, File Browser Guests, Picard |
| Network & System | Technitium, ntfy, Wireshark |
| Games | Factorio (192.168.2.220), Minecraft (192.168.2.222:25565) — status tiles, not real links |

Excluded (no web UI to link to): Twingate connector, Cloudflared tunnel,
registry-cache, image-cleanup, kube-state-metrics, configarr.

Icons: use Homarr's built-in icon picker (pulls from the dashboard-icons
project) instead of sourcing/committing PNGs to `assets/icon`.

Style: auto light/dark theme, a background image + accent colors carrying over
the visual idea from the old Homer config; Sonarr/Radarr/etc. widgets configured
with their API keys directly in the Homarr UI so those keys never touch git.

## Testing / verification

- `helm template services/homarr` renders cleanly with `common` dependency
  resolved.
- `sops -d services/homarr/secrets.yaml` decrypts with the repo's existing age
  key.
- After deploy: pod healthy, `dashboard.localhome.com` reachable, onboarding
  completes, board curation done via `claude-in-chrome`.
