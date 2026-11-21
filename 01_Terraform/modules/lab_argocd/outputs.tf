output "script" {
  description = "Shell that installs Argo CD from the repo values. Empty when install is false."
  value       = local.script
}

output "bootstrap" {
  description = "Bootstrap object for the kubernetes module. Null when install is false."
  value = var.install ? {
    manifest_urls = []
    helm_releases = []
    script        = local.script
  } : null
}

output "deploy_key" {
  description = "Generated deploy key. The lab repo is public, so bootstrap clones over HTTPS and does not install this key."
  value       = var.install ? tls_private_key.repo[0].public_key_openssh : null
}
