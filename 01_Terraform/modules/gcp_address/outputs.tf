output "addresses" {
  description = "Reserved addresses keyed by the logical name passed in."
  value = {
    for key, address in google_compute_address.this : key => {
      name      = address.name
      address   = address.address
      self_link = address.self_link
      id        = address.id
    }
  }
}
