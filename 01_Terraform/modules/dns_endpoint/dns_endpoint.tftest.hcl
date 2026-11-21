run "renders_api_name" {
  command = apply

  variables {
    hostname = "api.lab.example.com"
    address  = "203.0.113.10"
  }

  assert {
    condition = (
      output.manifest.kind == "DNSEndpoint" &&
      output.manifest.metadata.name == "api" &&
      output.manifest.metadata.namespace == "kube-system" &&
      output.manifest.metadata.labels["app.kubernetes.io/managed-by"] == "terraform" &&
      output.manifest.spec.endpoints[0].dnsName == "api.lab.example.com" &&
      output.manifest.spec.endpoints[0].recordType == "A" &&
      output.manifest.spec.endpoints[0].recordTTL == 300 &&
      jsonencode(output.manifest.spec.endpoints[0].targets) == jsonencode(["203.0.113.10"])
    )
    error_message = "The endpoint must publish the API hostname as an A record at the reserved address."
  }
}

run "absent_when_no_hostname" {
  command = apply

  variables {
    hostname = null
    address  = null
  }

  assert {
    condition     = output.manifest == null
    error_message = "A null hostname must not produce a DNSEndpoint."
  }
}

run "rejects_ip_hostname" {
  command = plan

  variables {
    hostname = "203.0.113.10"
    address  = "203.0.113.10"
  }

  expect_failures = [
    var.hostname,
  ]
}

run "rejects_prefix" {
  command = plan

  variables {
    hostname = "api.lab.example.com"
    address  = "203.0.113.10/32"
  }

  expect_failures = [
    var.address,
  ]
}

run "rejects_missing_address" {
  command = plan

  variables {
    hostname = "api.lab.example.com"
    address  = null
  }

  expect_failures = [
    terraform_data.inputs,
  ]
}
