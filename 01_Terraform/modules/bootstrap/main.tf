locals {
  helm_releases = [
    for release in var.helm_releases : {
      name       = release.name
      repository = release.repository
      chart      = release.chart
      version    = coalesce(release.version, "")
      namespace  = release.namespace
      values_yaml = (
        release.values_yaml == "" || endswith(release.values_yaml, "\n")
        ? release.values_yaml
        : "${release.values_yaml}\n"
      )
    }
  ]

  extra_script = trimspace(var.script)
  has_work     = length(var.manifest_urls) > 0 || length(local.helm_releases) > 0 || length(local.extra_script) > 0

  rendered = templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    manifest_urls = var.manifest_urls
    helm_releases = local.helm_releases
    extra_script  = local.extra_script
  })
}
