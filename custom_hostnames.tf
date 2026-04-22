# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   OpenTofu   ·   Cloudflare
#
#   Custom hostnames (SSL for SaaS)
#   `custom_hostnames.tfvars` + `manage_custom_hostnames = true`
#
# ════════════════════════════════════════════════════════════════════════════
#
#   External domains CNAME to your zone; Cloudflare issues and renews certs.
#   Import before first apply:
#   tofu import 'cloudflare_custom_hostname.hostname["<zone>:<host>"]' '<zid>/<id>'
#

resource "cloudflare_custom_hostname_fallback_origin" "fallback" {
  for_each = {
    for zone_key, zone in var.zones : zone_key => zone
    if lookup(zone, "manage_custom_hostnames", false) == true
  }

  zone_id = each.value.zone_id
  origin  = var.custom_hostname_fallback_origins[each.key]
}

locals {
  all_custom_hostnames = merge([
    for zone_key, hostnames in var.custom_hostnames : {
      for h in hostnames :
      "${zone_key}:${h.hostname}" => merge(h, {
        zone_id = var.zones[zone_key].zone_id
      })
      if lookup(var.zones[zone_key], "manage_custom_hostnames", false) == true
    }
  ]...)
}

resource "cloudflare_custom_hostname" "hostname" {
  for_each = local.all_custom_hostnames

  zone_id  = each.value.zone_id
  hostname = each.value.hostname

  ssl {
    method   = lookup(each.value, "ssl_method", "http")
    wildcard = lookup(each.value, "ssl_wildcard", false)
  }
}
