# mattermost-prod

The masterless control repo behind **https://chat.mikeharp.com** — a
production Mattermost server on one Hetzner VM, deployed and converged by
[puppet-mattermost](https://github.com/miharp/puppet-mattermost).

**Status: decommissioned (2026-08-13)** — the server was deliberately
deleted after proving the stack end to end (Vox Pupuli chose a Matrix
migration instead; this repo remains the rebuild recipe and plan B). A
final database dump and the secrets file were preserved off-box. The
deployment it ran: nginx TLS termination with Let's Encrypt, Mattermost
with a local PGDG PostgreSQL 16 via the module, outbound email through
SMTP submission, nightly database dumps, and a systemd timer re-applying
this repo every 30 minutes — validated end to end in
[mattermost-lab](https://github.com/miharp/mattermost-lab) first, then
live at chat.mikeharp.com for its shakedown day. See
[Rebuilding from scratch](#rebuilding-from-scratch) to resurrect it.

## The server

- `chat01` — Hetzner cx33 (4 vCPU x86, 8 GB, 80 GB), Rocky Linux 9, `nbg1`
- DNS: `chat.mikeharp.com` (A record at the registrar)
- Exposed ports: 22, 80, 443 only (firewalld); Mattermost listens on
  loopback behind nginx; PostgreSQL is local-only

## How changes happen

```console
# edit, then:
git commit && git push        # ...and within 30 minutes chat01 has converged
# impatient? on the server:
systemctl start puppet-apply
```

`puppet-apply.timer` runs [scripts/run-puppet](scripts/run-puppet): pull the
committed repo, `r10k puppetfile install`, `puppet apply`. Edits made directly
on the server are overwritten on the next run — except
`data/secrets.yaml`, which is gitignored and lives **only** on the server
(database password, SMTP mailbox password; see
[data/secrets.yaml.example](data/secrets.yaml.example)).

Mattermost settings are hiera data ([data/common.yaml](data/common.yaml)),
rendered by the module into `MM_*` environment variables. Settings managed
here show as environment-locked in the System Console; everything else stays
console-editable and persists.

## Email

Outbound mail goes through the `chat@mikeharp.com` mailbox (Bluehost) on
**port 587 with STARTTLS** — Hetzner blocks outbound 25/465 on newer cloud
accounts. Replies to notification emails land in that mailbox.

## Rebuilding from scratch

The VM is disposable by design; a rebuild is ~30 minutes:

1. Create an EL9 VM, point the DNS A record at it
2. `dnf install -y git && git clone https://github.com/miharp/mattermost-prod /opt/mattermost-prod`
3. Recreate `data/secrets.yaml` from the example (and your password manager)
4. `./scripts/bootstrap` — installs the OpenVox agent and r10k, then applies
   twice (the first pass serves HTTP and obtains the certificate — skipped
   cleanly if DNS hasn't propagated yet; the second upgrades nginx to TLS;
   the timer self-heals either way)
5. Restore the latest dump from `/var/backups/mattermost` (or off-site copy)

## Shakedown notes (learned the hard way, now encoded here)

- Hetzner's Rocky image ships **without firewalld** — `profile::base`
  installs and manages it
- `mattermost::manage_database` uses distro defaults, and EL9's default
  stream is PostgreSQL **13** (below Mattermost's required 14) —
  `profile::mattermost` declares `postgresql::globals` for PGDG 16. Beware
  on a host that already has PostgreSQL installed: dnf module streams share
  the `postgresql-server` package name, so an existing wrong-version install
  is left in place
- EL9's nginx is 1.20: use `listen 443 ssl http2;`, not the newer
  `http2 on;` directive
- The certbot exec is gated on `getent hosts <domain>` so pre-DNS applies
  skip it instead of failing

## Still deliberately missing

- **Off-site backups** — dumps rotate locally (14 days) in
  `/var/backups/mattermost`; ship them (and `/opt/mattermost/data`, until
  uploads move to object storage) to a Storage Box or S3 bucket
- **Object storage for uploads** — `FileSettings` stub in `data/common.yaml`
- **Monitoring** — at minimum an external uptime check against
  `https://chat.mikeharp.com/api/v4/system/ping`
