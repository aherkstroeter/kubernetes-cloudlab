# Phase 1: a workload file cannot choose a project

Phase 1 closes one hole. A file under `02_ArgoCD/03_workloads/` can no longer select `default` or `platform`, and can no longer aim its Application at another namespace. The `default` project can deploy nothing. The nine Applications that already exist keep the project and namespace they already have. The target this phase walks toward is [platform.md](platform.md).

## The hole

`02_ArgoCD/appsets/applicationset.yaml` generates one Application in the `argocd` namespace per `argo_app.yaml`. Applications in `argocd` may reference any AppProject, including one the file names itself ([applications in any namespace](https://argo-cd.readthedocs.io/en/latest/operator-manual/app-any-namespace/)). The template used to copy `project` and `namespace` straight out of the file.

Argo CD's own Git-generator guidance warns that a templated `project` field lets a writer of the source create an Application under a project with wider permissions ([Git generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)). The `default` project, when git does not define it, is the open project Argo CD creates: any repository, any destination, every kind. The root Application used that project. A workload file that set `project: default` or `project: platform` would have been applied with that project's authority on the next sync of `master`.

The generator now derives both fields from the directory. The values in the file are ignored. A check fails the pull request when a workload file disagrees with the directory, so a reader is not shown a project the cluster will not use.

## Path rules

The Git file generator's `.path.path` is the directory that contains the file. `.path.segments` is that directory split on `/`. The filename is `.path.filename` and is not a segment ([Git generator: files](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-generator-files)).

For `02_ArgoCD/03_workloads/www/argo_app.yaml`:

| Field | Value |
| --- | --- |
| `.path.path` | `02_ArgoCD/03_workloads/www` |
| `.path.segments[0]` | `02_ArgoCD` |
| `.path.segments[1]` | `03_workloads` |
| `.path.segments[2]` | `www` |
| `.path.filename` | `argo_app.yaml` |

The template sets:

- project `workloads` when segment 1 is `03_workloads`, and `platform` otherwise
- namespace to segment 2 for workloads

Platform and networking keep `.namespace` from the file. Those folder names are not the namespaces (`kube-vip` runs in `kube-system`, `envoy-gateway` in `envoy-gateway-system`, `metallb` in `metallb-system`).

The glob `02_ArgoCD/03_workloads/*/argo_app.yaml` requires one directory between the area and the file, so segment 2 exists for every workload the generator accepts. All nine current files already match these rules. The rendered Application specs stay the same.

`echo` remains a Service of type LoadBalancer. Banning that pattern is phase 4.

## The default project

Argo CD creates `default` if the object is missing, and the created object permits every repository, destination, and kind. The project can be modified. It cannot be deleted. Phase 1 therefore applies an explicit object that permits nothing, using the manifest from the [projects guide](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/#the-default-project), plus an empty `clusterResourceWhitelist`.

An empty `namespaceResourceWhitelist` still permits every namespaced kind. Namespaced kinds are denied with `namespaceResourceBlacklist`. Cluster-scoped kinds are allow-listed, so an empty `clusterResourceWhitelist` denies them. An empty `sourceRepos` matches no repository. An empty `destinations` matches no cluster. `sourceNamespaces` is empty, so an Application that lives outside `argocd` cannot select this project either.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: default
  namespace: argocd
spec:
  sourceRepos: []
  sourceNamespaces: []
  destinations: []
  clusterResourceWhitelist: []
  namespaceResourceBlacklist:
    - group: "*"
      kind: "*"
```

The object in git also carries sync-wave `-1` and a description. `platform` and `workloads` keep the specs they already had, one file each, under `02_ArgoCD/appsets/projects/`. Phase 1 does not remove `Namespace` from the workloads cluster-resource whitelist. That tightening arrives with tenant repositories.

## The root Application must recurse

A directory Application does not descend into subdirectories unless `spec.source.directory.recurse` is true. The root Application's path is `02_ArgoCD/appsets`. Without recurse, `projects/*.yaml` is never applied, the locked `default` never lands, and deleting the old `projects.yaml` would prune `platform` and `workloads` while leaving `default` open.

The root Application is `project: platform` and sets `directory.recurse: true`. `platform` already lists the `argocd` namespace and allows every cluster-scoped kind, so it can manage AppProjects and the ApplicationSet.

Argo CD does not watch `02_ArgoCD/bootstrap/root-app.yaml`. The live root Application syncs only `02_ArgoCD/appsets`. Changing the file in git does nothing to the live object until `kubectl apply`, or until server-0 boots and the install script applies whatever `master` it cloned.

## Order

Restricting `default` while the root Application still uses it stops the root Application from syncing.

1. Commit the files on local `master`.
2. `kubectl apply` the root Application from that commit, so it runs as `platform` with recurse on, while `default` is still the implicit open project.
3. Push `master`, then push that commit to `origin` `main`. Argo CD tracks `master` and then syncs the empty `default` project and the new ApplicationSet.
4. Confirm every Application is Synced and Healthy, nodes are Ready, `default` permits nothing, root's project is `platform`, and `www` and `echo` still target their own namespaces on project `workloads`.

A reboot of server-0 between the apply and the push clones the previous GitHub `master` and applies the old root Application (`project: default`). The window stays short. After the push, a boot applies the root Application this phase committed.

## Review and CI

`CODEOWNERS` names the files every tenant inherits:

- `02_ArgoCD/appsets/applicationset.yaml`
- `02_ArgoCD/appsets/projects/`
- `02_ArgoCD/bootstrap/root-app.yaml`
- the Gateway, GatewayClass, and EnvoyProxy manifests
- Argo CD values, external-dns values, and the ClusterIssuer
- the Argo CD install script and the VM startup templates

The file is the contract. GitHub enforces it when phase 2 turns on branch protection and required code-owner review. Phase 1 stays mergeable by the current owner.

`.github/workflows/checks.yml` does two things.

- `scripts/check-workload-projects.py` fails when a workload `argo_app.yaml` sets `project` to anything other than `workloads`, or `namespace` to anything other than its directory name. Absent keys pass. The generator would ignore a lie. The check keeps the file honest.
- `scripts/terraform-test.sh` runs `terraform test` in each module under `01_Terraform` that has a `.tftest.hcl` file. Those tests mock the Google provider or use no provider. The workflow does not plan the root configuration, because that plan needs credentials and the local state, and it does not receive cloud credentials.

## Left untouched

No GCS backend, no Terraform apply, no Gateway edit, no change to `echo`, no Pod Security, no NetworkPolicy, no tenant repository, no edit to the startup script, no Crossplane, and no replacement of the VMs. Human Roles and identity-provider groups stay in [platform.md](platform.md) as the matrix later objects have to fit.

## Key decisions

- **The directory is the authority for project and namespace.** The generator derives them from `.path.segments`. Copying the fields out of `argo_app.yaml` is what made a workload file an escalation. Platform folders keep the namespace from the file, because those folder names differ from the namespaces they run in.
- **A disagreeing file fails CI.** The generator ignores `project` and `namespace` in the file. The check still rejects a workload file that states a different pair, so the file cannot document a project the cluster will not use. Omitting the keys is valid.
- **`default` is the official deny, with an explicit empty cluster allow-list.** An empty namespaced allow-list does not deny namespaced kinds. `namespaceResourceBlacklist` of `*/*` does. The object has to exist, because Argo CD recreates an open `default` when the object is missing.
- **The root Application moves to `platform` before `default` is locked, and it recurses.** Argo CD does not sync `bootstrap/root-app.yaml` by itself. Subdirectory manifests are skipped when recurse is left at its default. Applying the updated root Application before the push is what lets the locked project and the split files land.
- **CODEOWNERS is recorded and not yet enforced.** Phase 2 is the branch protection that makes GitHub require the owner. Writing the file now is the list phase 2 turns on.
- **Module tests run in CI. The root configuration does not.** The root plan needs the cloud credentials and the state file. The module tests are the ones that already run offline.

## PR plan

Phase 2 is what adds branch protection, so this phase lands as two commits on `master`. Argo CD tracks that branch. Each commit is one concern.

1. **ADD document the platform target and phase 1.** Files: `docs/platform.md`, `docs/phase-1-safe-trunk.md`. No code. Depends on nothing.
2. **MOD stop workload apps from choosing a project.** Files: the ApplicationSet template, `02_ArgoCD/appsets/projects/` (and removal of `projects.yaml`), the root Application (`project: platform`, `directory.recurse: true`), `CODEOWNERS`, `scripts/check-workload-projects.py`, `scripts/terraform-test.sh`, and `.github/workflows/checks.yml`. Depends on commit 1 only as the write-up of the same change.

Later phases in [platform.md](platform.md) are separate efforts. They are not pull requests of this change.
