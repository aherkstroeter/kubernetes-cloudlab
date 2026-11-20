run "empty" {
  command = apply

  assert {
    condition     = output.script == ""
    error_message = "No inputs should render no script."
  }
}

run "manifest_only" {
  command = apply

  variables {
    manifest_urls = ["https://example.com/argocd/install.yaml", "https://example.com/argocd/root-app.yaml"]
  }

  assert {
    condition     = strcontains(output.script, "https://example.com/argocd/install.yaml") && strcontains(output.script, "https://example.com/argocd/root-app.yaml") && strcontains(output.script, "k3s kubectl apply")
    error_message = "Manifest URLs should be applied with k3s kubectl."
  }

  assert {
    condition     = !strcontains(output.script, "get-helm-3")
    error_message = "Helm should not be installed when no chart was requested."
  }
}

run "helm_then_manifest" {
  command = apply

  variables {
    manifest_urls = ["https://example.com/root-app.yaml"]
    helm_releases = [{
      name        = "argocd"
      repository  = "https://argoproj.github.io/argo-helm"
      chart       = "argo-cd"
      version     = "7.7.0"
      namespace   = "argocd"
      values_yaml = "server:\n  replicas: 1\n"
    }]
    script = "k3s kubectl -n argocd get deploy"
  }

  assert {
    condition     = can(regex("(?s)helm upgrade --install 'argocd'.*apply_url 'https://example.com/root-app.yaml'.*k3s kubectl -n argocd get deploy", output.script))
    error_message = "Helm must run before manifests, and the extra script must run last."
  }

  assert {
    condition     = strcontains(output.script, "--version '7.7.0'") && strcontains(output.script, "--namespace 'argocd'") && strcontains(output.script, "replicas: 1")
    error_message = "Chart version, namespace, and values must be preserved."
  }
}
