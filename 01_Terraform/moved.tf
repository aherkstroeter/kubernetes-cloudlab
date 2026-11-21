moved {
  from = google_service_account.nodes
  to   = module.lab_dns.google_service_account.nodes
}

moved {
  from = google_project_iam_member.node_dns_reader
  to   = module.lab_dns.google_project_iam_member.node_dns_reader
}

moved {
  from = google_dns_managed_zone_iam_member.node_dns_admin
  to   = module.lab_dns.google_dns_managed_zone_iam_member.node_dns_admin
}

moved {
  from = google_dns_record_set.api
  to   = module.lab_dns_records.google_dns_record_set.api
}

moved {
  from = google_dns_record_set.service
  to   = module.lab_dns_records.google_dns_record_set.service
}

moved {
  from = google_compute_firewall.github_hooks
  to   = module.github_hooks.google_compute_firewall.hooks
}

moved {
  from = data.http.github_meta
  to   = module.github_hooks.data.http.github_meta
}

moved {
  from = tls_private_key.argocd_repo
  to   = module.lab_argocd.tls_private_key.repo
}
