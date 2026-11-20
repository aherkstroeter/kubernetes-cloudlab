locals {
  template_vars = {
    cluster_token   = var.cluster_token
    channel         = var.channel
    server_urls     = var.server_urls
    tls_sans        = var.tls_sans
    tls_san_command = var.tls_san_command
    node_ip_command = var.node_ip_command
  }

  primary_server_script = templatefile("${path.module}/templates/install.sh.tftpl", merge(local.template_vars, {
    role               = "server"
    cluster_init       = true
    include_server_url = false
    retry_count        = var.primary_retries
    extra_args         = var.extra_server_args
  }))

  server_script = templatefile("${path.module}/templates/install.sh.tftpl", merge(local.template_vars, {
    role               = "server"
    cluster_init       = false
    include_server_url = true
    retry_count        = var.join_retries
    extra_args         = var.extra_server_args
  }))

  agent_script = templatefile("${path.module}/templates/install.sh.tftpl", merge(local.template_vars, {
    role               = "agent"
    cluster_init       = false
    include_server_url = true
    retry_count        = var.join_retries
    extra_args         = var.extra_agent_args
  }))
}
