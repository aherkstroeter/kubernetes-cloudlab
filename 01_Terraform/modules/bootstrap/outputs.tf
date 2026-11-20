output "script" {
  description = "A complete bash script that waits for the Kubernetes API, installs Helm releases, applies manifests, then runs the extra script. Empty when there is nothing to do."
  value       = local.has_work ? local.rendered : ""
}
