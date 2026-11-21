#!/usr/bin/env bash
# Merge a fake admin kubeconfig into copies. The real files are only hashed.
# A failure prints field paths, never certificate or key material.
set -euo pipefail
umask 077

script_dir=$(cd "$(dirname "$0")" && pwd)
installer="${script_dir}/install-kubeconfig.sh"
real="${KUBECONFIG_SRC:-/home/cyb3rcy6er/kubeconfig}"
dotkube="${HOME}/.kube/config"
context="gcp-k3s-test-cluster"
server="https://api.lab.example.com:6443"
dummy_ca="Y2EtZmFrZQ=="
dummy_cert="Y2VydC1mYWtl"
dummy_key="a2V5LWZha2U="

if [[ ! -f "$real" || ! -f "$dotkube" ]]; then
  echo "FAIL missing kubeconfig fixture" >&2
  exit 1
fi

work=$(mktemp -d)
chmod 700 "$work"
trap 'shred -u "$work"/* "$work"/*/* 2>/dev/null || true; rm -rf "$work"' EXIT

hash_real_before=$(sha256sum "$real")
hash_dot_before=$(sha256sum "$dotkube")

cat > "${work}/admin.yaml" << EOF
apiVersion: v1
kind: Config
clusters:
- name: default
  cluster:
    certificate-authority-data: ${dummy_ca}
    server: https://127.0.0.1:6443
contexts:
- name: default
  context:
    cluster: default
    user: default
users:
- name: default
  user:
    client-certificate-data: ${dummy_cert}
    client-key-data: ${dummy_key}
current-context: default
EOF
chmod 600 "${work}/admin.yaml"

cat > "${work}/two.yaml" << 'EOF'
apiVersion: v1
kind: Config
clusters:
- name: one
  cluster:
    server: https://one.example.com:6443
- name: two
  cluster:
    server: https://two.example.com:6443
contexts:
- name: one
  context:
    cluster: one
    user: one
users:
- name: one
  user:
    token: not-used
current-context: one
EOF
chmod 600 "${work}/two.yaml"

cp "$real" "${work}/real.yaml"
cp "$dotkube" "${work}/dot.yaml"
chmod 600 "${work}/real.yaml" "${work}/dot.yaml"

mkdir -p "${work}/parent/fresh"
chmod 755 "${work}/parent"

export INSTALLER="$installer"
set +e
python3 - "$work" "$context" "$server" "$dummy_ca" "$dummy_cert" "$dummy_key" "$real" "$dotkube" << 'PY'
import hashlib, os, stat, subprocess, sys, shutil
import yaml

work, context, server, dummy_ca, dummy_cert, dummy_key, real, dotkube = sys.argv[1:]
installer = os.environ["INSTALLER"]
# The shell hashes these two files around this process. Touch neither of them.
if not os.path.isfile(real) or not os.path.isfile(dotkube):
    print("FAIL real kubeconfig fixture missing")
    sys.exit(1)
admin = os.path.join(work, "admin.yaml")
failed = False

def say(status, message):
    global failed
    if status != "PASS":
        failed = True
    print(f"{status} {message}")

def load(path):
    with open(path) as fh:
        return yaml.safe_load(fh)

def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        h.update(fh.read())
    return h.hexdigest()

def others(doc, name):
    def keep(items):
        return [item for item in (items or []) if item.get("name") != name]
    return {
        "contexts": keep(doc.get("contexts")),
        "clusters": keep(doc.get("clusters")),
        "users": keep(doc.get("users")),
    }

def diff_paths(before, after, prefix=""):
    paths = []
    if before == after:
        return paths
    if isinstance(before, dict) and isinstance(after, dict):
        for key in list(before) + [key for key in after if key not in before]:
            child = f"{prefix}.{key}" if prefix else str(key)
            if key not in before or key not in after:
                paths.append(child)
            else:
                paths.extend(diff_paths(before[key], after[key], child))
        return paths
    if isinstance(before, list) and isinstance(after, list):
        if len(before) != len(after):
            paths.append(f"{prefix} len {len(before)}!={len(after)}")
            return paths
        for i, (left, right) in enumerate(zip(before, after)):
            paths.extend(diff_paths(left, right, f"{prefix}[{i}]"))
        return paths
    paths.append(prefix or "<root>")
    return paths

def named(doc, kind, name):
    for item in doc.get(kind) or []:
        if item.get("name") == name:
            return item
    return None

def merge(dest, server_url, admin_path=admin, extra=None):
    env = os.environ.copy()
    env["KUBECONFIG"] = dest
    cmd = [
        "bash", installer,
        "--from-file", admin_path,
        "--context", context,
        "--server", server_url,
    ]
    if extra:
        cmd.extend(extra)
    return subprocess.run(cmd, env=env, text=True, capture_output=True)

def check_merge(label, src, current_override=None):
    dest = os.path.join(work, f"{label}.yaml")
    shutil.copy(src, dest)
    os.chmod(dest, 0o600)
    before = load(dest)
    if current_override:
        before["current-context"] = current_override
        with open(dest, "w") as fh:
            yaml.safe_dump(before, fh, sort_keys=False)
        os.chmod(dest, 0o600)
        before = load(dest)
    result = merge(dest, server)
    if result.returncode != 0:
        say("FAIL", f"{label} merge exited {result.returncode}")
        err = (result.stderr or "").strip().splitlines()
        if err:
            print(" ", err[-1])
        return
    after = load(dest)
    problems = []
    other_paths = diff_paths(others(before, context), others(after, context))
    if other_paths:
        problems.append("other entries changed: " + ", ".join(other_paths))
    kept = {key: before.get(key) for key in before if key not in ("clusters", "contexts", "users", "current-context")}
    for key, value in kept.items():
        if after.get(key) != value:
            problems.append(f"top-level {key} changed")
    mode = stat.S_IMODE(os.stat(dest).st_mode)
    if mode != 0o600:
        problems.append(f"mode {oct(mode)}")
    cluster = named(after, "clusters", context)
    user = named(after, "users", context)
    ctx = named(after, "contexts", context)
    if not cluster or cluster.get("cluster", {}).get("server") != server:
        problems.append("server was not rewritten to the hostname")
    if not user or user.get("user", {}).get("client-certificate-data") != dummy_cert:
        problems.append("client cert was not taken from the admin file")
    if not user or user.get("user", {}).get("client-key-data") != dummy_key:
        problems.append("client key was not taken from the admin file")
    ca = (cluster or {}).get("cluster", {}).get("certificate-authority-data")
    if ca != dummy_ca:
        problems.append("cluster CA was not taken from the admin file")
    if not ctx or ctx.get("context") != {"cluster": context, "user": context}:
        problems.append("context does not point at the renamed cluster and user")
    previous = before.get("current-context")
    expect = previous if previous and previous != context else context
    if after.get("current-context") != expect:
        problems.append("current-context was not preserved")
    if problems:
        say("FAIL", f"{label}: " + "; ".join(problems))
    else:
        say("PASS", label)

def check_reject(label, server_url, admin_path=admin):
    dest = os.path.join(work, f"reject-{label}.yaml")
    shutil.copy(os.path.join(work, "real.yaml"), dest)
    os.chmod(dest, 0o600)
    before_hash = digest(dest)
    parent_mode = stat.S_IMODE(os.stat(os.path.dirname(dest)).st_mode)
    result = merge(dest, server_url, admin_path=admin_path)
    after_hash = digest(dest)
    parent_after = stat.S_IMODE(os.stat(os.path.dirname(dest)).st_mode)
    if result.returncode == 0:
        say("FAIL", f"reject {label} was accepted")
        return
    if before_hash != after_hash:
        say("FAIL", f"reject {label} changed the destination")
        return
    if parent_mode != parent_after:
        say("FAIL", f"reject {label} changed the parent mode")
        return
    say("PASS", f"reject {label}")

check_merge("real-current", os.path.join(work, "real.yaml"))
real_doc = load(os.path.join(work, "real.yaml"))
other_names = [item["name"] for item in real_doc["contexts"] if item["name"] != context]
if len(other_names) != 1:
    say("FAIL", f"expected one other context, found {len(other_names)}")
else:
    check_merge("real-other-current", os.path.join(work, "real.yaml"), current_override=other_names[0])
check_merge("dotkube", os.path.join(work, "dot.yaml"))

# Second merge of an already merged copy stays stable.
stable_src = os.path.join(work, "real-current.yaml")
stable_before = load(stable_src)
check_merge("real-second", stable_src)
stable_after = load(os.path.join(work, "real-second.yaml"))
second_paths = diff_paths(stable_before, stable_after)
if second_paths:
    say("FAIL", "second merge changed: " + ", ".join(second_paths))
else:
    say("PASS", "second merge is stable")

check_reject("ip", "https://10.0.0.1:6443")
check_reject("http", "http://api.lab.example.com:6443")
check_reject("port", "https://api.lab.example.com:443")
check_reject("missing-port", "https://api.lab.example.com")
check_reject("two-entries", server, admin_path=os.path.join(work, "two.yaml"))

fresh_dir = os.path.join(work, "parent", "fresh")
os.chmod(os.path.join(work, "parent"), 0o755)
fresh = os.path.join(fresh_dir, "config")
parent_before = stat.S_IMODE(os.stat(os.path.join(work, "parent")).st_mode)
result = merge(fresh, server)
parent_after = stat.S_IMODE(os.stat(os.path.join(work, "parent")).st_mode)
if result.returncode != 0:
    say("FAIL", f"fresh file exited {result.returncode}")
else:
    doc = load(fresh)
    mode = stat.S_IMODE(os.stat(fresh).st_mode)
    problems = []
    if doc.get("current-context") != context:
        problems.append("current-context")
    if len(doc.get("contexts") or []) != 1 or len(doc.get("clusters") or []) != 1 or len(doc.get("users") or []) != 1:
        problems.append("entry count")
    if mode != 0o600:
        problems.append(f"mode {oct(mode)}")
    if parent_before != 0o755 or parent_after != 0o755:
        problems.append("parent mode changed")
    if problems:
        say("FAIL", "fresh file: " + ", ".join(problems))
    else:
        say("PASS", "fresh file")

first = os.path.join(work, "split-first.yaml")
second = os.path.join(work, "split-second.yaml")
shutil.copy(os.path.join(work, "real.yaml"), first)
shutil.copy(os.path.join(work, "real.yaml"), second)
os.chmod(first, 0o600)
os.chmod(second, 0o600)
second_before = digest(second)
split_env = os.environ.copy()
split_env["KUBECONFIG"] = first + os.pathsep + second
split = subprocess.run(
    ["bash", installer, "--from-file", admin, "--context", context, "--server", server],
    env=split_env, text=True, capture_output=True,
)
if split.returncode != 0:
    say("FAIL", f"split KUBECONFIG exited {split.returncode}")
elif digest(second) != second_before:
    say("FAIL", "split KUBECONFIG wrote the second file")
elif (named(load(first), "clusters", context) or {}).get("cluster", {}).get("server") != server:
    say("FAIL", "split KUBECONFIG did not rewrite the first file")
else:
    say("PASS", "split KUBECONFIG")

scratch = os.path.join(work, "unused-dest.yaml")
missing_env = os.environ.copy()
missing_env["KUBECONFIG"] = scratch
missing = subprocess.run(
    ["bash", installer, "--server", server, "--from-file", admin],
    env=missing_env, text=True, capture_output=True,
)
if missing.returncode != 2:
    say("FAIL", f"missing context exited {missing.returncode}")
elif os.path.exists(scratch):
    say("FAIL", "missing context wrote a kubeconfig")
else:
    say("PASS", "missing context")

sys.exit(1 if failed else 0)
PY
status=$?
set -e

hash_real_after=$(sha256sum "$real")
hash_dot_after=$(sha256sum "$dotkube")
if [[ "$hash_real_before" != "$hash_real_after" || "$hash_dot_before" != "$hash_dot_after" ]]; then
  echo "FAIL a real kubeconfig changed" >&2
  exit 1
fi
if [[ "$status" -ne 0 ]]; then
  echo "FAIL kubeconfig merge" >&2
  exit "$status"
fi
echo "PASS real kubeconfig files were not modified"
echo "PASS install-kubeconfig"
exit 0
