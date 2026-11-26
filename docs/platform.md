# A platform other teams deploy on

This repository is the product a central platform team offers to other teams. Product teams deploy from their own repositories. People and agents who build the platform work on branches of this repository. One CI job applies infrastructure after merge. This document is the target. Phases after the first are specified here and are not built by the phase 1 change.

Three roles match the Gateway API personas ([roles and personas](https://gateway-api.sigs.k8s.io/docs/concepts/roles-and-personas/)). One person can hold more than one role. The boundary between roles is a repository boundary and an AppProject boundary.

| Role | Owns | Ships by |
| --- | --- | --- |
| Infrastructure (Ian) | This cloud account: VPC, NAT, firewall, reserved addresses, passthrough forwarding rules, the instance group, and the node service account. Terraform in `01_Terraform/` is that layer. | A reviewed change to this repository. CI applies it. |
| Platform (Chihiro) | The product other teams consume: Argo CD, AppProjects, ApplicationSets, GatewayClass, the shared Gateway, cert-manager, external-dns, external-secrets, and later Crossplane providers, XRDs, and Compositions. | A reviewed change to this repository. Onboarding a team is a platform change: a prefix, a project, a generator, quotas, and policy. |
| Application (Ana) | One apps repository for her team. Plain manifests under a directory the platform already constrained. HTTPRoutes on a Gateway the platform installed. | A merge in that apps repository. Argo CD applies it. She does not select an AppProject, create a Namespace, reserve an address, or open a pull request here to deploy. |

Tenants never see a forwarding rule. A future management cluster is where Crossplane would provision more workload clusters. This cluster cannot host the controller that creates it, so its bootstrap stays Terraform.

Argo CD is the steady-state applier of cluster objects. Terraform is the steady-state applier of GCP, including the two cluster objects that are the infrastructure contract (the MetalLB pool and the API DNSEndpoint), until a management cluster takes those over. The server-0 boot script installs Argo CD once on a cluster that does not have it. It is not a reconciler.

## How a team ships

This follows Kartverket's apps-repository architecture ([SKIP, 2024-04-22](https://skip.kartverket.no/blog/introducing-apps-repositories)). Argo CD's own guidance is the same split between application source and config.

```text
teamname-apps/
  env/
    <cluster>/
      <prefix-namespace>/
        deployment.yaml
        service.yaml
        httproute.yaml
```

A platform-owned ApplicationSet reads `env/*/*`. The template hardcodes `project: <team>`. The destination namespace is the directory name. Teams do not write Application, ApplicationSet, or AppProject objects. A small `config.json` per directory, parsed by `templatePatch`, may later flip a fixed set of booleans (autoSync, prune, selfHeal). It cannot set project, repo, cluster, or namespace. UI edits live in Argo CD's database and vanish when the pod restarts, so the directory stays the source of truth.

The AppProject allows destinations `namespace: '<prefix>-*'` and `sourceRepos` equal to that one apps repository. The prefix is unique and assigned at onboarding. ApplicationSets and AppProjects stay in this repository. A team that can edit them can add an exclusion and leave the prefix.

`02_ArgoCD/03_workloads/` holds the platform team's own examples (`echo`, `www`). New tenant apps do not go there. The www pipeline is the artifact story to generalize: the source repository builds an immutable image tag, and the config repository pins that tag. The tenant does not commit into this repository to roll out.

CODEOWNERS and branch protection are how two platform engineers review a Gateway change. They are not how an application team deploys.

## Promotion

For the config repository Argo CD watches, the established model is one trunk. Each environment is a directory. Promotion is a pull request that copies a pin (an image tag or digest) from one directory to another ([Kostis Kapelonis, 2021-12-17](https://codefresh.io/blog/stop-using-branches-deploying-different-gitops-environments/)). Long-lived branches named test, staging, and production conflict, reorder commits, and hide what the target already runs. Feature branches stay in the application source repository.

Kartverket encodes the same idea as `env/<cluster>/<namespace>/`. Non-prod and prod are different clusters watching different directories of the same trunk. Moving a manifest between cluster directories is the promotion.

This lab has one cluster. It can demonstrate two teams. It shares nodes, the Gateway, the address pool, and the failure domain, so a namespace on it is not a staging environment. A second cluster is the point at which a second environment is real.

Argo CD reconciles one target. It does not wait until an environment is healthy and then move the next pin. That step is separate: a pull request opened after the lower directory is Healthy, or later the GitOps Promoter ([technology preview, 2026-11-17](https://developers.redhat.com/articles/2026/11/17/gitops-promoter-technology-preview)). The Promoter writes hydrated branches with health gates. Humans still author one dry trunk. Adopting it sits on top of the pin model.

Preview environments are directories a pipeline creates and removes (`<prefix>-<branch>`). The pull-request generator has to live on an ApplicationSet in the `argocd` namespace. For agents working in parallel, a preview per branch is how they run at the same time. ResourceQuota and delete-on-close matter on a five-node cluster.

## Several people or agents

An agent that ships an application is an application tenant. Its own apps repository or prefix, its own preview namespace, and credentials that can write only there keep it off another tenant's files.

What runs in parallel for application work:

- One apps repository, or one prefix, per stream of work.
- The finished output is a branch and a pull request. Argo CD applies after merge. `selfHeal` restores any live edit the trunk already manages.
- Image tags are the source commit, as `www` already does.
- Each open branch gets a preview directory and a namespace `<prefix>-<branch>`. Closing the pull request removes the directory, the Application, and the namespace.
- A required check rejects cluster-scoped kinds and rejects files outside that team's `env/` tree.

Application agents still share the cluster edge. external-dns `policy: sync`, the address pool, and the wildcard listener are cluster-wide. The empty cluster-resource whitelist and admission are what stop a preview from taking another team's hostname or spending a load-balancer address.

Credentials are part of the boundary. A process holding the admin kubeconfig, the cloud credentials, and push access to this repository is a platform admin. An application agent gets git credentials for its apps repository and, if it must inspect the cluster, a kubeconfig limited to its prefix.

Building this repository is a different problem. Several people or agents can hold branches at the same time. Apply stays a single CI job.

- Branch protection on `master`. Direct pushes stop once phase 2 is in place. Until then, phase 1 stays mergeable by the current owner.
- A merge queue rebases, re-runs the checks on the combination, and merges one at a time. Two green pull requests can still break when combined.
- Terraform moves to a GCS backend with a lock. The pull request runs `terraform plan`. Apply runs in CI after the queue merges. Laptops and agents do not apply. Locking the whole configuration at plan time would freeze every other pull request. The state lock during apply, plus a fresh plan inside the queue, is the coordination that still lets authors plan together. A plan that would destroy or replace instances, reserved addresses, forwarding rules, or the instance group fails unless a person has labeled the pull request.
- Argo CD changes get a rendered diff from [argocd-diff-preview](https://github.com/dag-andersen/argocd-diff-preview) on an ephemeral cluster in CI. The job needs the repository and the charts. It does not receive the lab kubeconfig, and it cannot sync the lab.
- The usual change is a new file. A directory under `02_ArgoCD/02_platform/<name>/` is picked up by the existing glob. Each AppProject is its own file. Each Terraform module call moves to its own file in a later phase. A new hostname is a ListenerSet or an HTTPRoute in that app's directory.
- A short list stays shared because every tenant inherits it. Feature work leaves it alone. `CODEOWNERS` names that list. An agent task names one directory, and CI fails the pull request when the diff leaves it. A person can touch several directories in one pull request.
- A platform agent gets its own worktree and branch, permission to push that branch, and no permission to push `master`. It does not run `terraform apply`, and it does not receive an admin kubeconfig. It does not edit the startup script to publish a change. Terraform ignores `metadata_startup_script` after create, and replacing server-0 while the other servers form a quorum can start a second etcd.

Apply of this cluster's Terraform stays one CI job. A change to Argo CD, the Gateway, external-dns, or the ApplicationSet template stays one reviewed pull request. The boot script on the running VM is not a way to publish a platform change.

## Where the Applications live

Kartverket generates Applications in the `argocd` namespace and hardcodes the project. That holds while tenants cannot create or edit those Application objects.

CECG ([2025-04-09](https://www.cecg.io/blog/multi-tenant-argocd)) puts each tenant's Applications in their own namespace and lists that namespace on `spec.sourceNamespaces` for their project only. An Application outside `argocd` may use a project only when the project lists its namespace. Applications that live in `argocd` may still reference any project. That exception is why a workload file must not be able to select `default` or `platform`.

Argo CD generates an Application in the same namespace as the ApplicationSet ([applications in any namespace](https://argo-cd.readthedocs.io/en/latest/operator-manual/app-any-namespace/), issue 11104). Moving Applications into tenant namespaces means the ApplicationSet moves with them.

Phase 1 uses Kartverket's placement. This repository holds every ApplicationSet. Generated Applications stay in `argocd`. The generator derives the project from the directory. The `default` project permits nothing. The root Application runs as `platform`, which is the project that may create AppProjects and ApplicationSets.

A team moves to CECG's placement when that team may author Application objects. The ApplicationSet then lives in a namespace only they use, that namespace is listed on their project's `sourceNamespaces`, and it is absent from `platform` and `default`. The `argocd` namespace is never a tenant `sourceNamespace`.

One Argo CD serves mutually trusting employees of one company ([Dan Garfield and Jesse Suen, 2022-02-14](https://blog.argoproj.io/best-practices-for-multi-tenancy-in-argo-cd-273e25a047b0)). A second Argo CD instance is the response to a real trust boundary, or to a repository allowed to run Jsonnet, Helm plugins, or Kustomize remote bases. Those renderers execute with Argo CD's credentials. The first tenant contract is plain YAML. Helm from a repository the AppProject already lists can come later, as a `config.json` tool value the template understands. Jsonnet, remote bases, and config-management plugins stay off.

## The tenancy boundary

Argo CD applies as itself. A namespace Role does not constrain a teammate who only pushes git. The full human role matrix waits. The boundary below does not.

Before any other team's pod runs:

- Project `default` permits nothing. Workload authors cannot select a project. The generator derives it. Phase 1 does this part.
- The tenant AppProject's `sourceRepos` is their apps repository. `destinations` is `<prefix>-*`. `clusterResourceWhitelist` is empty. They cannot sync Namespace, ClusterRole, ClusterRoleBinding, CustomResourceDefinition, StorageClass, Gateway, or GatewayClass. A directory that syncs a Namespace named `kube-system` can delete it. `CreateNamespace=true` on the Application is the platform creating the namespace. A Namespace document in the apps repository is denied. Namespaces are platform-owned.
- `managedNamespaceMetadata` sets `pod-security.kubernetes.io/enforce: baseline` and the team label. Baseline rejects privileged, hostPath, and hostNetwork. Restricted is the goal once the contract is ordinary Deployments. An audit label logs and does not block.
- ResourceQuota and LimitRange land with the namespace.
- NetworkPolicy is default-deny between tenant namespaces, allows DNS, and allows ingress from `envoy-gateway-system`. Egress to the GCE metadata address `169.254.169.254` is denied. On this cluster the node service account can read the Argo CD OIDC secret, the webhook secret, and DNS in the zone. Any pod that can reach the metadata server can act as that account. k3s on GCE does not provide GKE Workload Identity. A later per-namespace identity is how a tenant secret store gets credentials of its own. A ClusterSecretStore, if one is added, stays platform-scoped. Tenant ExternalSecrets bind a store that can read only that prefix.
- No Service of type LoadBalancer. That spends an address from the infrastructure pool and publishes DNS beside the Gateway. `echo` is the current example of that shape and stays until phase 4. New apps do not copy it.
- AppProject cannot constrain fields. A validating admission policy rejects a LoadBalancer Service, a hostPath volume, a privileged container, and a Certificate whose dnsNames are outside the names delegated to that namespace. That policy is installed with the first foreign workload.
- Tenants do not receive cluster-admin, the `argocd` namespace, or a binding that can create Application or AppProject objects.

Human logins, when a second person exists, map identity-provider groups to the matrix below. `policy.csv` grants `role:admin` to one Google account. The configured Google token carries email. Group claims are an OIDC change at that time. Dex stays off. kubectl Roles are for a shell inside the prefix. They are not the deploy path.

| Role | Git | Argo CD | kubectl | Cloud |
| --- | --- | --- | --- | --- |
| Infrastructure | `01_Terraform/` via the reviewed trunk. Apply from CI. | none required | break-glass only | this cloud account |
| Platform | this repository's platform paths and the onboarding objects | admin | cluster-admin | provider credentials, separate from the node account |
| Application | their apps repository only | get and sync on their project | namespace Role inside the prefix, when they need a shell | none; later, namespaced claims in their namespace |

## Gateway

The platform owns Gateway `lab` and its wildcard listener for `*.lab.anselmherkstroeter.com`. `allowedRoutes` selects namespaces the platform has labeled at onboarding. The application admin writes an HTTPRoute.

A ListenerSet is how the platform delegates a name outside that wildcard. `www` already does this for the apex and `www.anselmherkstroeter.com`. `allowedListeners` becomes that delegation list. The default is none.

Today the halves point the other way: `allowedRoutes` is `Same`, so a tenant namespace cannot attach an HTTPRoute, and `allowedListeners` is `All`, so any namespace Argo CD can write may attach a ListenerSet. external-dns `policy: sync` will publish that name and can delete other names in the zone. Phase 4 turns this around. Phase 1 leaves the Gateway as it is.

A Certificate is an application object for a name that delegation already lists. The ClusterIssuer stays cluster-wide. Until admission or a cert-manager approver is installed, the platform creates the Certificate and the tenant owns the HTTPRoute, the Deployment, and a ClusterIP Service.

external-dns keeps the zone filter, the owner id, and `policy: sync`. The hostname rule is what keeps sync from becoming a way to take someone else's name.

## Tenant cloud objects

Crossplane, when it is installed, is a platform API. The platform owns ProviderConfigs, XRDs, and Compositions. Tenants create namespaced composite resources in their namespace. Their AppProject whitelists the platform API group and does not whitelist provider groups, so a tenant manifest cannot contain a raw GCP address or an IAM member. The schema is the policy: role enums, no admin roles, and a separate kind for a grant versus a provisioned object.

A Composition edit is served to every consuming claim immediately. That is a production change for every tenant. A breaking change is a new XRD. The MetalLB pool and the API DNSEndpoint stay the platform contract. Provider credentials are a dedicated identity. They are not the node service account.

Offboarding is the same object as onboarding. An Application finalizer plus a Crossplane deletion policy of Delete removes the namespace, the DNS name, and the cloud object when the directory goes away. Prune and selfHeal stay on. `allowEmpty` stays off, so an empty directory does not wipe a namespace. Removing the directory removes the Application, and the finalizer removes the objects. That removal is a reviewed merge in the apps repository.

## Decisions held with the target

These get expensive after a second team exists.

- **One writer.** The server-0 boot script clones this repository on every boot and helm-upgrades Argo CD, then reapplies the root Application. That is a second writer on objects Argo CD manages. Terraform ignores `metadata_startup_script` after create, so the script on the running VM is not guaranteed to match git. The next cluster's template installs Argo CD only when it is absent, then stops. Replacing the current fleet to push a script is a separate decision.
- **Git does not rebuild the cluster.** Terraform creates the nodes. The one-shot bootstrap applies the root Application. Argo CD syncs. Terraform state and etcd are not in git.
- **Remote state and CI** are how a second person or agent changes infrastructure. One state for this cluster.
- **Secrets have one seam.** external-secrets, with a store per tenant prefix. No sealed secrets in git, and no second path for application secrets.
- **Images are pinned.** A floating tag makes the directory model unable to say what is deployed. `www` already pins a commit tag.
- **Automated prune stays on** for tenant apps. The review on the apps-repository pull request is the gate.
- **Failed-sync notifications** are the first operability feature once another team depends on a deploy. Notifications are off.
- **Shared blast radius is accepted until the second cluster.** One Gateway, one zone with `policy: sync`, and later one Composition, means a bad platform commit hits every tenant. Tenant repositories cannot contain platform objects.
- **Onboarding and offboarding are the same object.** Prefix, project, generator, quota, network policy, pod security, secret identity, delegated names. Deleting that object, with finalizers, is the offboarding.

Leave these until the boundary above exists: a portal, a service mesh, an Argo CD instance per team, a virtual cluster per team, moving this cluster's Terraform into Crossplane, and letting tenants pick arbitrary namespace names.

## North star

A management cluster runs Argo CD, Crossplane providers, and policy. Workload clusters are created from there. Terraform remains how this cluster was born, until that management cluster exists. Crossplane v2 namespaced composite resources are the tenant cloud API. Tenant projects whitelist that API group and do not whitelist provider groups. A breaking change is a new XRD. A Composition edit is a production change for every claim.

Each product team has an apps repository, `env/<cluster>/<prefix-namespace>/`. Platform-owned ApplicationSets hardcode the project. When a team is allowed to author Application objects, those objects live in their namespace and `sourceNamespaces` lists only that namespace. The `argocd` namespace is never on that list. The first contract is plain YAML. Helm comes later, from a repository the project already lists. Jsonnet, Kustomize remote bases, and config-management plugins stay off.

The thing that gets promoted is an immutable pin: an image digest, or a hydrated manifest revision. Non-prod and prod are different clusters. A controller opens the next promotion only after the lower environment is Healthy. Hand-merged environment branches are not that mechanism.

The cluster enforces what AppProject cannot express. Tenant namespaces are Pod Security `restricted`. Admission rejects a LoadBalancer Service, hostPath, a privileged container, a Namespace manifest, and a Certificate for a name the platform did not delegate. NetworkPolicy is default-deny, including the GCE metadata address. Each tenant namespace has its own cloud identity. Argo CD roles bind identity-provider groups.

Platform authors work on branches. A merge queue re-plans the combination. Terraform state is remote and locked. Apply runs in CI after merge. A plan that would replace an instance, an address, or a forwarding rule fails closed. Pull requests show the manifests Argo CD would render, from an ephemeral cluster, with no lab kubeconfig in the job. An agent task names one directory. Cluster-scoped platform changes land on a non-prod cluster before production.

Steady state has one writer per object. Bootstrap runs once. Offboarding is a reviewed deletion in the apps repository, and finalizers remove the namespace, the DNS name, and the claims.

## Phases

Each phase is a reasonable place to stop. Later phases assume the earlier ones.

1. **The trunk cannot escalate.** A file under `03_workloads/` cannot select `default` or `platform`, and cannot aim a workload at another namespace. The `default` project can deploy nothing. The nine apps that exist today keep the project and namespace they already have. Specified in [phase-1-safe-trunk.md](phase-1-safe-trunk.md).
2. **CI is the only Terraform applier.** GCS backend and a lock, plan on the pull request, apply from CI after a merge queue, branch protection, and CODEOWNERS enforced. A destructive plan fails unless a person labeled the pull request. Module calls in `01_Terraform/main.tf` become one file per module.
3. **Authors see the rendered diff.** argocd-diff-preview on an ephemeral cluster. The job cannot sync the lab.
4. **One tenant ships from their own repository.** An example apps repository, a prefix, an ApplicationSet that hardcodes the project, baseline Pod Security, quota, a default-deny NetworkPolicy that blocks the metadata address, Gateway `allowedRoutes` by namespace label, and ListenerSets only where a hostname was delegated. `echo`'s LoadBalancer stops being the pattern new apps copy. Previews are a directory per branch with a quota and delete-on-close.
5. **Fields AppProject cannot see are rejected.** Admission for Service type, hostPath, privileged pods, and Certificate dnsNames. Tenant ExternalSecrets bind a store scoped to the prefix. The node service account is not a tenant identity.
6. **The next cluster has one writer.** The bootstrap template installs Argo CD when it is absent, then stops. The running VMs stay as they are.
7. **A second environment is a second cluster.** Pins move between `env/<cluster>/` directories after the lower one is Healthy. This cluster is not asked to stand in for staging.
8. **Tenants can ask for cloud objects.** Crossplane XRDs, namespaced, with provider credentials dedicated to the provider. Tenant projects cannot sync provider CRDs. Bootstrap of this cluster stays Terraform.
9. **The remainder of the north star.** A management cluster, health-gated promotion, identity-provider groups in place of the single admin email, per-namespace workload identity, and Applications in tenant namespaces for teams that author them. A portal comes after phase 4 is actually in use.
