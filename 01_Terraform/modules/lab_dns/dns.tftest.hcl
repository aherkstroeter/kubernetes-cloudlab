mock_provider "google" {
  mock_data "google_dns_managed_zone" {
    defaults = {
      name         = "example-com"
      dns_name     = "example.com."
      name_servers = ["ns1.example.net."]
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email = "lab-nodes@example-project.iam.gserviceaccount.com"
      id    = "lab-nodes"
      name  = "projects/example-project/serviceAccounts/lab-nodes@example-project.iam.gserviceaccount.com"
    }
  }
}

run "binds_named_secrets" {
  command = apply

  variables {
    project_id   = "example-project"
    cluster_name = "lab"
    dns_domain   = "example.com"
    secret_ids   = ["argocd-oidc-google", "argocd-github-webhook"]
  }

  assert {
    condition = (
      length(google_secret_manager_secret_iam_member.node_accessor) == 2 &&
      google_secret_manager_secret_iam_member.node_accessor["argocd-oidc-google"].role == "roles/secretmanager.secretAccessor" &&
      google_secret_manager_secret_iam_member.node_accessor["argocd-oidc-google"].secret_id == "argocd-oidc-google" &&
      google_secret_manager_secret_iam_member.node_accessor["argocd-github-webhook"].role == "roles/secretmanager.secretAccessor" &&
      google_secret_manager_secret_iam_member.node_accessor["argocd-github-webhook"].secret_id == "argocd-github-webhook" &&
      google_secret_manager_secret_iam_member.node_accessor["argocd-oidc-google"].member == "serviceAccount:lab-nodes@example-project.iam.gserviceaccount.com"
    )
    error_message = "The node account must be secretAccessor on each named secret and on nothing else."
  }
}

run "skips_bindings_when_dns_is_off" {
  command = plan

  variables {
    project_id   = "example-project"
    cluster_name = "lab"
    dns_domain   = null
    secret_ids   = ["argocd-oidc-google"]
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.node_accessor) == 0 && length(google_service_account.nodes) == 0
    error_message = "No zone means no node account and no secret binding."
  }
}

run "skips_bindings_when_no_secrets" {
  command = plan

  variables {
    project_id   = "example-project"
    cluster_name = "lab"
    dns_domain   = "example.com"
    secret_ids   = []
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.node_accessor) == 0 && length(google_service_account.nodes) == 1
    error_message = "An empty secret list must leave the node account in place and grant no Secret Manager role."
  }
}
