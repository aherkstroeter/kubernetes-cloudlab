run "renders_sorted_prefixes" {
  command = apply

  variables {
    addresses = ["203.0.113.11", "203.0.113.10"]
  }

  assert {
    condition = (
      jsonencode(output.cidrs) == jsonencode(["203.0.113.10/32", "203.0.113.11/32"]) &&
      output.ip_address_pool.kind == "IPAddressPool" &&
      output.ip_address_pool.metadata.name == "public" &&
      output.ip_address_pool.metadata.namespace == "metallb-system" &&
      output.ip_address_pool.metadata.labels["app.kubernetes.io/managed-by"] == "terraform" &&
      output.ip_address_pool.spec.autoAssign == true &&
      jsonencode(output.ip_address_pool.spec.addresses) == jsonencode(["203.0.113.10/32", "203.0.113.11/32"]) &&
      output.l2_advertisement.kind == "L2Advertisement" &&
      jsonencode(output.l2_advertisement.spec.ipAddressPools) == "[\"public\"]"
    )
    error_message = "The pool must list each reserved address as a sorted /32 and advertise it."
  }
}

run "empty_pool_is_absent" {
  command = apply

  variables {
    addresses = []
  }

  assert {
    condition     = output.ip_address_pool == null && output.l2_advertisement == null && length(output.cidrs) == 0
    error_message = "An empty address list must not produce MetalLB objects."
  }
}

run "rejects_prefix" {
  command = plan

  variables {
    addresses = ["203.0.113.10/32"]
  }

  expect_failures = [
    var.addresses,
  ]
}
