# kubernetes-cloudlab

A private k3s cluster on GCP. Terraform builds the network, the VMs, and the reserved addresses. Argo CD installs everything inside the cluster from this repository.

People use hostnames. The nodes have no public address of their own.

## Where to look

| Path | What it is |
| --- | --- |
| `01_Terraform` | GCP, plus the two in-cluster objects the cluster cannot invent: the MetalLB pool and the API DNS name |
| `02_ArgoCD/01_networking` | kube-vip, MetalLB, Envoy Gateway, external-dns |
| `02_ArgoCD/02_platform` | Argo CD, cert-manager, External Secrets |
| `02_ArgoCD/03_workloads` | Apps. Echo is the test Service |
| `02_ArgoCD/appsets` | The ApplicationSet that turns each app folder into one Application |
| `02_ArgoCD/bootstrap` | The root Application. It is the only in-cluster manifest the boot script applies |
| `01_Terraform/scripts/install-kubeconfig.sh` | Merges this cluster into the local kubeconfig after a rebuild |

An app folder holds `argo_app.yaml` and, when the app is a Helm chart, `values.yaml`. The values file lists only the choices that differ from the pinned chart. Manifests that are not part of the chart live in `manifests/`.

## Two applies

`terraform apply` in `01_Terraform` creates the cluster. Leave `kubeconfig_path` unset for that apply. Terraform plans every resource before it creates any, and a `kubernetes_manifest` reads the CRD schema while it plans. MetalLB and external-dns are not installed yet, so the pool and the API name cannot be in that plan.

When the API is up and those CRDs exist, set `kubeconfig_path` and apply again. That second apply adds the pool and the API DNSEndpoint. It does not rebuild the VMs. Unsetting `kubeconfig_path` later plans a destroy of those objects.

`terraform.tfvars` and `*.auto.tfvars` are gitignored. Copy `01_Terraform/terraform.tfvars.example`.

## What this repo does not own

The Cloud DNS zone, DNSSEC, Secret Manager secret versions, the Google OAuth client, and the GitHub webhook registration live outside Terraform. Destroying the cluster must leave them in place. A secret value, a kubeconfig, and the cluster token do not belong in git.
