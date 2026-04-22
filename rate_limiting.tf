# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   OpenTofu   ·   Cloudflare
#
#   Rate limiting — /catalog
#   Rulesets API (not legacy Rate Limiting API)
#
# ════════════════════════════════════════════════════════════════════════════
#
#   Key: `cf.colo.id` + `ip.src` — distributed scrapers rotating many IPs at
#   one edge still hit the limit at that colo faster than per-IP alone.
#

resource "cloudflare_ruleset" "rate_limiting" {
  for_each = { for k, v in var.zones : k => v if v.rate_limit_catalog_enabled }

  zone_id = each.value.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_ratelimit"

  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"/catalog\")"
    description = "Rate limit catalog searches — ${each.key}"
    enabled     = true

    ratelimit {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = each.value.rate_limit_catalog.period
      requests_per_period = each.value.rate_limit_catalog.requests_per_period
      mitigation_timeout  = each.value.rate_limit_catalog.block_duration
    }
  }
}
