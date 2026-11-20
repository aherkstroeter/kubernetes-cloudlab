run "scripts" {
  command = apply

  variables {
    cluster_token     = "test-token-value"
    channel           = "stable"
    server_urls       = ["https://10.0.0.2:6443", "https://primary.example.internal:6443"]
    tls_sans          = ["primary.example.internal"]
    node_ip_command   = "echo 10.0.0.2"
    extra_server_args = ["--write-kubeconfig-mode=600"]
  }

  assert {
    condition     = strcontains(output.primary_server_script, "--cluster-init") && !strcontains(output.primary_server_script, "select_server_url")
    error_message = "The primary script must initialize the cluster and must not look up a join URL."
  }

  assert {
    condition     = strcontains(output.server_script, "https://10.0.0.2:6443") && strcontains(output.server_script, "https://primary.example.internal:6443") && !strcontains(output.server_script, "--cluster-init")
    error_message = "Extra servers must join the given URLs without initializing a new cluster."
  }

  assert {
    condition     = strcontains(output.agent_script, "agent") && strcontains(output.agent_script, "https://10.0.0.2:6443") && !strcontains(output.agent_script, "--cluster-init") && !strcontains(output.agent_script, "--tls-san")
    error_message = "Agents must join and must not receive server-only flags."
  }

  assert {
    condition     = strcontains(output.primary_server_script, "set +x") && !strcontains(output.primary_server_script, "set -x") && strcontains(output.primary_server_script, "test-token-value") && strcontains(output.primary_server_script, "--write-kubeconfig-mode=600")
    error_message = "The token must be embedded, xtrace must stay off, and extra server args must be kept."
  }
}

run "quoted_token" {
  command = apply

  variables {
    cluster_token = "p@ss'word$"
    server_urls   = ["https://10.0.0.2:6443"]
  }

  assert {
    condition     = strcontains(output.primary_server_script, "p@ss'word$")
    error_message = "A token with quotes and a dollar sign must round-trip into the heredoc."
  }
}
