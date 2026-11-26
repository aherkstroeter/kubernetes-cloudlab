#!/usr/bin/env bash
# Run terraform test in each module under 01_Terraform that has a .tftest.hcl file.
# The root configuration is not planned: that plan needs cloud credentials and state.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/01_Terraform"

found=0
while IFS= read -r -d '' testfile; do
  dir=$(dirname "$testfile")
  echo "== terraform test in 01_Terraform/${dir}"
  terraform -chdir="$dir" init -backend=false -input=false
  terraform -chdir="$dir" test -no-color
  found=1
done < <(find modules -name '*.tftest.hcl' -print0 | sort -z)

if [[ "$found" -eq 0 ]]; then
  echo "no terraform tests found under 01_Terraform/modules" >&2
  exit 1
fi
