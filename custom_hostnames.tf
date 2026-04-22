# ── Custom hostname management ──────────────────────────────────────
# For SaaS / SSL for SaaS: external domains CNAME to your zone with
# certificates from Cloudflare. Data in custom_hostnames.tfvars; only
# zones with manage_custom_hostnames = true in main.tfvars are included.
#
# Import existing hostnames before first apply, e.g.:
#   tofu import 'cloudflare_custom_hostname.hostname["<zone-key>:<hostname>"]' '<zone_id>/<id>'

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
