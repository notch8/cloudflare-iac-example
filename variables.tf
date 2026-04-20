# ── Variables ───────────────────────────────────────────────────────
#
# The `zones` map is the single source of truth for which Cloudflare
# zones get protection and how aggressive each one is. Adding a new
# zone is one tfvars entry + one `tofu apply`.
#
# Every feature is opt-out (defaults to true) so a bare minimum zone
# definition just needs zone_id and host_filter.

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone, WAF, Rulesets, and Bot Management edit permissions."
  type        = string
  sensitive   = true
}

variable "account_name" {
  description = "Human-readable name for this Cloudflare account. Used for tagging and documentation only."
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID (from the dashboard right sidebar)."
  type        = string
}

variable "zones" {
  description = "Map of Cloudflare zones to protect, keyed by a stable short name."
  type = map(object({
    # Required
    zone_id     = string
    host_filter = string # e.g. "example.com" — used to scope block rules to tenant hosts

    # Feature toggles (all default to true)
    waf_custom_rules_enabled   = optional(bool, true)
    rate_limit_catalog_enabled = optional(bool, true)
    bot_fight_mode             = optional(bool, true)
    site24x7_bot_skip          = optional(bool, true)

    # Rate-limit tuning per zone
    rate_limit_catalog = optional(object({
      requests_per_period = optional(number, 10)
      period              = optional(number, 10)
      block_duration      = optional(number, 10)
    }), {})

    # Extra hostnames that share this zone (e.g. vanity domains pointing
    # at the same origin). The managed challenge rule will apply to these too.
    extra_hosts = optional(list(string), [])
  }))
}
