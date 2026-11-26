#!/usr/bin/env python3
"""Fail when a workload argo_app.yaml disagrees with its directory.

The ApplicationSet derives project and namespace from the directory and ignores
these keys. Absent keys pass. A present project must be workloads. A present
namespace must be the directory name. Pass a repository root as the first
argument; the default is the repository that contains this script.
"""

import sys
from pathlib import Path


def field(text, key):
    prefix = key + ":"
    for line in text.splitlines():
        if line.startswith(" ") or line.startswith("\t") or line.startswith("#"):
            continue
        if not line.startswith(prefix):
            continue
        raw = line[len(prefix) :].strip()
        if " #" in raw:
            raw = raw.split(" #", 1)[0].strip()
        if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in {'"', "'"}:
            raw = raw[1:-1]
        return raw
    return None


def main(argv):
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[1]
    workloads = root / "02_ArgoCD" / "03_workloads"
    if not workloads.is_dir():
        print(f"missing {workloads}", file=sys.stderr)
        return 1
    errors = []
    files = sorted(workloads.glob("*/argo_app.yaml"))
    for path in files:
        directory = path.parent.name
        text = path.read_text()
        project = field(text, "project")
        namespace = field(text, "namespace")
        if project is not None and project != "workloads":
            errors.append(f"{path}: project is {project!r}, expected 'workloads'")
        if namespace is not None and namespace != directory:
            errors.append(f"{path}: namespace is {namespace!r}, expected {directory!r}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"ok: {len(files)} workload argo_app.yaml file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
