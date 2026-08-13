# mattermost-prod

A masterless control repo that runs a production Mattermost server on one
Hetzner VM using [puppet-mattermost](https://github.com/miharp/puppet-mattermost):
nginx TLS termination with Let's Encrypt, Mattermost + local PostgreSQL via
the module, nightly database dumps, and a systemd timer that re-applies the
committed repo every 30 minutes.

The stack this deploys is the one validated end to end in
[mattermost-lab](https://github.com/miharp/mattermost-lab) — EL9 (arm64 or
amd64), SELinux enforcing, archive install — plus the TLS/backup layer a
real deployment needs.

## Server

- Hetzner CAX21 (4 vCPU arm64, 8 GB) or CPX21 — either is ample headroom
  for a ~250-member community (Mattermost sizes 1,000 users at 2 vCPU/4 GB)
- Image: **Rocky Linux 9**
- DNS: an A/AAAA record for the chat domain pointing at the server,
  **before** bootstrap (Let's Encrypt validates over HTTP)

## Prerequisites

- The module repo must be clonable by r10k on the server: either make
  `miharp/puppet-mattermost` public, or configure a read-only deploy key
  and switch the Puppetfile URL to SSH. Same applies to this repo itself.

## Bootstrap

```console
ssh root@<server>
dnf install -y git
git clone https://github.com/miharp/mattermost-prod /opt/mattermost-prod
cd /opt/mattermost-prod

# Set the real domain and contact address:
vi data/common.yaml            # mattermost::site_url, letsencrypt_email
cp data/secrets.yaml.example data/secrets.yaml
vi data/secrets.yaml           # real database password

./scripts/bootstrap
```

Bootstrap applies twice on purpose: the first pass brings up HTTP-only
nginx and obtains the certificate, the second upgrades the vhost to TLS.
After that, `puppet-apply.timer` keeps the server converged with whatever
is committed — the operational loop is *commit, push, wait* (or
`systemctl start puppet-apply` to not wait).

Edits made on the server directly (including `data/common.yaml`) are
overwritten by the next timer run's `git pull`; `data/secrets.yaml` is the
one file that lives only on the server.

## What's deliberately not here yet

- **Off-site backups** — dumps rotate locally in `/var/backups/mattermost`;
  ship them (and `/opt/mattermost/data`, until uploads move to object
  storage) to a Hetzner Storage Box or S3 bucket
- **Object storage for uploads** — `FileSettings` example is stubbed in
  `data/common.yaml`; enabling it makes the VM disposable
- **SMTP** — invites and email notifications need it; example stubbed in
  `data/common.yaml`
- **Monitoring** — at minimum an external uptime check against
  `https://<domain>/api/v4/system/ping`
