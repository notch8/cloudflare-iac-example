# ── Outputs ─────────────────────────────────────────────────────────
#
# Handy summary after apply — at a glance, which zones are protected
# and which features are enabled per zone. Useful for code review and
# for "did I remember to turn this on?" sanity checks.

output "protected_zones" {
  description = "Summary of zones with protection applied."
  value = {
    for k, v in var.zones : k => {
      zone_id                    = v.zone_id
      host                       = v.host_filter
      bot_fight_mode             = v.bot_fight_mode
      waf_custom_rules_enabled   = v.waf_custom_rules_enabled
      rate_limit_catalog_enabled = v.rate_limit_catalog_enabled
      site24x7_bot_skip          = v.site24x7_bot_skip
    }
  }
}
