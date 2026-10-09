#!/usr/bin/env python3
"""Delete expired certificates from OPNsense via its REST API.

Credentials are read from the environment (see .env.example):
  OPNSENSE_HOST, OPNSENSE_API_KEY, OPNSENSE_API_SECRET

Dry-run is the default; pass --apply to actually delete.
"""

import argparse
import os
import sys
from datetime import datetime

import requests
import urllib3

# Certificate search endpoints differ between OPNsense versions; try them in order.
POSSIBLE_ENDPOINTS = [
    "trust/cert/search",                # current Trust API
    "core/trust/search",
    "system/certificate/search",        # older System API
    "core/certificates/search",
    "certificates/certificate/search",  # legacy Certificates API
]


def env(name):
    value = os.getenv(name)
    if not value:
        sys.exit(f"Environment variable {name} is not set (see .env.example)")
    return value


class OPNsense:
    def __init__(self, host, key, secret, verify_ssl, dry_run):
        self.host = host.rstrip("/")
        self.auth = (key, secret)
        self.verify_ssl = verify_ssl
        self.dry_run = dry_run

    def request(self, method, endpoint, quiet_404=False):
        url = f"{self.host}/api/{endpoint.lstrip('/')}"
        if self.dry_run and method == "POST":
            print(f"  [DRY-RUN] {method} {url}")
            return {"result": "dry-run"}
        try:
            r = requests.request(method, url, auth=self.auth, verify=self.verify_ssl, timeout=10)
            if quiet_404 and r.status_code == 404:
                return None
            r.raise_for_status()
            return r.json() if r.text else {}
        except requests.exceptions.RequestException as e:
            if not quiet_404:
                print(f"  API error {method} {url}: {e}")
            return None


def find_certificates(api):
    print("Detecting certificate API endpoint...")
    for ep in POSSIBLE_ENDPOINTS:
        result = api.request("GET", ep, quiet_404=True)
        if result and "rows" in result:
            print(f"  found: /api/{ep}")
            return ep.removesuffix("/search"), result["rows"]
        print(f"  /api/{ep}: not available")
    return None, None


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--before", required=True, help="delete certificates valid until before this date (YYYY-MM-DD)")
    p.add_argument("--apply", action="store_true", help="really delete (default is dry-run)")
    p.add_argument("--insecure", action="store_true", help="skip TLS verification (self-signed GUI cert)")
    args = p.parse_args()

    if args.insecure:
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    api = OPNsense(env("OPNSENSE_HOST"), env("OPNSENSE_API_KEY"), env("OPNSENSE_API_SECRET"),
                   verify_ssl=not args.insecure, dry_run=not args.apply)
    if api.dry_run:
        print("DRY-RUN mode: nothing will be deleted. Use --apply to delete.\n")

    base, rows = find_certificates(api)
    if rows is None:
        sys.exit("No certificate API endpoint matched, or the API key has no access.")

    cutoff = datetime.strptime(args.before, "%Y-%m-%d")
    expired = []
    for cert in rows:
        valid_to = (cert.get("valid_to") or "").split(" ")[0]
        try:
            if datetime.strptime(valid_to, "%Y-%m-%d") < cutoff:
                expired.append((cert.get("uuid") or cert.get("refid"),
                                cert.get("descr") or cert.get("name") or "unknown", valid_to))
        except ValueError:
            continue

    if not expired:
        print(f"\nNo certificates expiring before {args.before}.")
        return

    print(f"\nCertificates expiring before {args.before}: {len(expired)}")
    for cert_id, name, valid_to in expired:
        print(f"- {name} (valid to {valid_to})")
        api.request("POST", f"{base}/del/{cert_id}")
    print("\nDone.")


if __name__ == "__main__":
    main()
