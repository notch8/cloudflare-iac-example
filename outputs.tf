# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   OpenTofu   ·   Cloudflare
#
#   Outputs
#   Post-apply summary — zones, flags, optional resource counts
#
# ════════════════════════════════════════════════════════════════════════════

output "protected_zones" {
  description = "Summary of zones with protection and optional DNS / custom hostname flags."
  value = {
    for k, v in var.zones : k => {
      zone_id                    = v.zone_id
      host                       = v.host_filter
      bot_fight_mode             = v.bot_fight_mode
      waf_custom_rules_enabled   = v.waf_custom_rules_enabled
      rate_limit_catalog_enabled = v.rate_limit_catalog_enabled
      site24x7_bot_skip          = v.site24x7_bot_skip
      cache_rules                = v.cache_rules
      manage_dns                 = v.manage_dns
      manage_custom_hostnames    = v.manage_custom_hostnames
    }
  }
}

output "dns_records_managed_count" {
  description = "Number of DNS records managed (zones with manage_dns only)."
  value       = length(local.all_dns_records)
}

output "custom_hostnames_managed_count" {
  description = "Number of custom hostnames managed (zones with flag only)."
  value       = length(local.all_custom_hostnames)
}
