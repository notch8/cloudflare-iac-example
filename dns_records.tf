# ── DNS record management ───────────────────────────────────────────
# Populated from envs/<account>/dns.tfvars. Only created for zones
# with manage_dns = true in main.tfvars.
#
# Import existing records before first apply, e.g.:
#   tofu import 'cloudflare_record.dns["<zone-key>:<record-name>"]' <zone_id>/<record_id>

locals {
  all_dns_records = merge([
    for zone_obj in var.dns_records : {
      for record in zone_obj.records :
      "${zone_obj.zone}:${record.name}" => merge(record, {
        zone_id = var.zones[zone_obj.zone].zone_id
      })
      if lookup(var.zones[zone_obj.zone], "manage_dns", false) == true
    }
  ]...)
}

resource "cloudflare_record" "dns" {
  for_each = local.all_dns_records

  zone_id         = each.value.zone_id
  name            = each.value.name
  type            = each.value.type
  content         = each.value.content
  ttl             = lookup(each.value, "ttl", 1)
  proxied         = lookup(each.value, "proxied", false)
  comment         = lookup(each.value, "comment", "DNS managed by Terraform")
  allow_overwrite = false

  lifecycle {
    prevent_destroy = true
  }
}
