# ── Rate Limiting ───────────────────────────────────────────────────
#
# Rate-limits /catalog requests to prevent bot-driven CPU/DB saturation.
# Uses the Cloudflare Rulesets API (not the deprecated Rate Limiting API).
#
# Keyed by Cloudflare colo + source IP: if a distributed scraper rotates
# through 200 IPs at one colo, they'll trip the limit at that colo faster
# than a pure per-IP limit would catch them.

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
