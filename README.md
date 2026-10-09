# OPNsense Toolkit

Scripts I use to automate routine work on OPNsense firewalls: API-driven cleanup,
log shipping and a KVM lab for testing changes before production.

| Folder | What it does | Stack |
|---|---|---|
| [`cert-cleanup/`](cert-cleanup) | Finds and deletes expired certificates through the OPNsense REST API | Python, requests |
| [`log-fetcher/`](log-fetcher) | Pulls parsed connection logs from the firewall and ships them to a log server (cron) | Bash, SSH/SCP |
| [`kvm-lab/`](kvm-lab) | Bootstraps an OPNsense VM for testing: API key, SSH, management-access lockdown | sh, PHP (OPNsense config API), pf |

## cert-cleanup

- Auto-detects the certificate API endpoint, since it differs between OPNsense versions
- **Dry-run by default**: lists what would be deleted, and deletes only with `--apply`
- Credentials come from environment variables, never from the code

```bash
cp cert-cleanup/.env.example .env && set -a && . ./.env && set +a
python3 cert-cleanup/opnsense_cert_cleanup.py --before 2025-01-01 --insecure          # dry run
python3 cert-cleanup/opnsense_cert_cleanup.py --before 2025-01-01 --insecure --apply  # delete
```

The API key needs access to *System: Certificate Manager*.

## log-fetcher

Copies `connections_*.txt` files from the firewall to a central log server over SSH/SCP.
A file is removed from the firewall **only after** it was delivered successfully. Results are logged.

```bash
# crontab -e
*/5 * * * * OPNSENSE_HOST=192.0.2.1 REMOTE_USER=logs REMOTE_HOST=logs.example.com /opt/scripts/opnsense_fetcher.sh
```

Requires key-based SSH access to both the firewall and the log server.

## kvm-lab

Helpers for a disposable OPNsense VM under libvirt/KVM. Run them on the firewall console:

| Script | Purpose |
|---|---|
| `enable-ssh.sh` | Enables SSH through OPNsense's own `write_config()`, with a direct `config.xml` edit as a fallback, then applies it via `configctl` |
| `bootstrap-api.sh` | Generates an API key/secret for `root` (the secret is stored bcrypt-hashed, like the GUI does) |
| `restrict-mgmt.sh` | Idempotently adds `quick` block rules, so SSH and GUI on LAN are reachable only from `MGMT_HOST` |
| `verify-mgmt.sh` | Checks the resulting `pf` ruleset and the sshd state |

```sh
MGMT_HOST=192.168.124.1 sh restrict-mgmt.sh
MGMT_HOST=192.168.124.1 sh verify-mgmt.sh
```

> ⚠️ `enable-ssh.sh` turns on root login with a password. It is meant for an isolated lab VM only.
> Every script backs up `/conf/config.xml` before making changes.
