run "installs_production_values" {
  command = apply

  variables {
    install = true
  }

  assert {
    condition = (
      strcontains(output.script, "helm upgrade --install 'argocd' 'argo/argo-cd'") &&
      strcontains(output.script, "--version '10.18.2'") &&
      strcontains(output.script, "02_ArgoCD/02_platform/argocd/values.yaml") &&
      strcontains(output.script, "02_ArgoCD/bootstrap/root-app.yaml") &&
      strcontains(output.script, "certificates.cert-manager.io") &&
      !strcontains(output.script, "already exists")
    )
    error_message = "Bootstrap must helm-install the production values file and must not skip an existing release."
  }
}

run "skipped" {
  command = apply

  variables {
    install = false
  }

  assert {
    condition     = output.script == "" && output.bootstrap == null && output.deploy_key == null
    error_message = "install false should produce no script, bootstrap, or key."
  }
}
