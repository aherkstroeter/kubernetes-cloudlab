#!/usr/bin/env bash
# Fetch this cluster's admin kubeconfig and merge one context into the local file.
# Other contexts stay. A mismatch restores the previous file and exits 1.
# Pass --from-file to merge a kubeconfig you already have. That skips IAP.
set -euo pipefail
umask 077

usage() {
  echo "usage: install-kubeconfig.sh --context NAME --server https://HOST:6443 [--project ID --zone ZONE --instance NAME | --from-file PATH]" >&2
}

project=""
zone=""
instance=""
context=""
server=""
from_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) project="${2:-}"; shift 2 ;;
    --zone) zone="${2:-}"; shift 2 ;;
    --instance) instance="${2:-}"; shift 2 ;;
    --context) context="${2:-}"; shift 2 ;;
    --server) server="${2:-}"; shift 2 ;;
    --from-file) from_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$context" || -z "$server" ]]; then
  usage
  exit 2
fi
if [[ -n "$from_file" ]]; then
  if [[ ! -f "$from_file" ]]; then
    echo "admin kubeconfig not found" >&2
    exit 1
  fi
elif [[ -z "$project" || -z "$zone" || -z "$instance" ]]; then
  usage
  exit 2
fi

if [[ -n "${KUBECONFIG:-}" ]]; then
  dest="${KUBECONFIG%%:*}"
else
  dest="${HOME}/.kube/config"
fi
mkdir -p "$(dirname "$dest")"

work=$(mktemp -d)
chmod 700 "$work"
admin="${work}/admin.yaml"
backup="${work}/backup.yaml"
out="${work}/out.yaml"
trap 'shred -u "$work"/* 2>/dev/null || true; rm -rf "$work"' EXIT

if [[ -n "$from_file" ]]; then
  cp "$from_file" "$admin"
else
  deadline=$((SECONDS + 300))
  until gcloud compute ssh "$instance" \
    --project "$project" \
    --zone "$zone" \
    --tunnel-through-iap \
    --quiet \
    --command 'test -f /etc/rancher/k3s/k3s.yaml'
  do
    if (( SECONDS >= deadline )); then
      echo "k3s.yaml was not on the instance before the deadline" >&2
      exit 1
    fi
    sleep 2
  done
  gcloud compute ssh "$instance" \
    --project "$project" \
    --zone "$zone" \
    --tunnel-through-iap \
    --quiet \
    --command 'sudo cat /etc/rancher/k3s/k3s.yaml' > "$admin"
fi
chmod 600 "$admin"

if [[ -f "$dest" ]]; then
  cp "$dest" "$backup"
  chmod 600 "$backup"
fi

set +e
CONTEXT="$context" SERVER="$server" DEST="$dest" ADMIN="$admin" BACKUP="$backup" OUT="$out" python3 - << 'PY'
import os, sys, ipaddress
from urllib.parse import urlparse
import yaml

context = os.environ["CONTEXT"]
server = os.environ["SERVER"]
dest = os.environ["DEST"]
admin_path = os.environ["ADMIN"]
backup = os.environ["BACKUP"]
out = os.environ["OUT"]

parsed = urlparse(server)
try:
    ipaddress.ip_address(parsed.hostname or "")
    is_ip = True
except ValueError:
    is_ip = False
if parsed.scheme != "https" or not parsed.hostname or parsed.port != 6443 or is_ip:
    sys.exit("server must be https://hostname:6443")

def load(path):
    with open(path) as fh:
        doc = yaml.safe_load(fh) or {}
    if not isinstance(doc, dict):
        sys.exit("kubeconfig is not a mapping")
    return doc

def named(items, name):
    found = [item for item in (items or []) if item.get("name") == name]
    return found

def replace_named(items, name, new_item):
    items = list(items or [])
    for i, item in enumerate(items):
        if item.get("name") == name:
            items[i] = new_item
            return items
    items.append(new_item)
    return items

def others(doc, name):
    def keep(items):
        return [item for item in (items or []) if item.get("name") != name]
    return {
        "contexts": keep(doc.get("contexts")),
        "clusters": keep(doc.get("clusters")),
        "users": keep(doc.get("users")),
    }

admin = load(admin_path)
clusters = admin.get("clusters") or []
contexts = admin.get("contexts") or []
users = admin.get("users") or []
if len(clusters) != 1 or len(contexts) != 1 or len(users) != 1:
    sys.exit("admin kubeconfig must contain one cluster, one context, and one user")

cluster = clusters[0]["cluster"]
cluster["server"] = server
new_cluster = {"name": context, "cluster": cluster}
new_context = {
    "name": context,
    "context": {"cluster": context, "user": context},
}
new_user = {"name": context, "user": users[0]["user"]}

existing = load(dest) if os.path.exists(dest) else {}
previous = existing.get("current-context")
before = others(existing, context)

merged = {key: value for key, value in existing.items() if key not in ("clusters", "contexts", "users", "current-context")}
merged["apiVersion"] = existing.get("apiVersion") or admin.get("apiVersion") or "v1"
merged["kind"] = existing.get("kind") or admin.get("kind") or "Config"
merged["clusters"] = replace_named(existing.get("clusters"), context, new_cluster)
merged["contexts"] = replace_named(existing.get("contexts"), context, new_context)
merged["users"] = replace_named(existing.get("users"), context, new_user)
if previous and previous != context:
    merged["current-context"] = previous
else:
    merged["current-context"] = context

with open(out, "w") as fh:
    yaml.safe_dump(merged, fh, default_flow_style=False, sort_keys=False)
os.chmod(out, 0o600)

written = load(out)
after = others(written, context)
if before != after:
    sys.exit("another context changed; the kubeconfig was left as it was")
if previous and previous != context:
    if written.get("current-context") != previous:
        sys.exit("current-context changed; the kubeconfig was left as it was")
elif written.get("current-context") != context:
    sys.exit("current-context was not set to this cluster")

os.replace(out, dest)
os.chmod(dest, 0o600)
PY
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  if [[ -f "$backup" ]]; then
    cp "$backup" "$dest"
    chmod 600 "$dest"
  elif [[ ! -f "$dest" ]]; then
    :
  fi
  exit "$status"
fi
