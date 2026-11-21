output "cidrs" {
  description = "Pool prefixes, sorted."
  value       = local.cidrs
}

output "ip_address_pool" {
  description = "IPAddressPool manifest. Null when addresses is empty."
  value       = length(local.cidrs) == 0 ? null : local.ip_address_pool
}

output "l2_advertisement" {
  description = "L2Advertisement manifest. Null when addresses is empty."
  value       = length(local.cidrs) == 0 ? null : local.l2_advertisement
}
