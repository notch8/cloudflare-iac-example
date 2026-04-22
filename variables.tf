# ── Variables ───────────────────────────────────────────────────────
#
# The `zones` map is the single source of truth for which Cloudflare
# zones get protection and how aggressive each one is. Adding a new
# zone is one tfvars entry + one `tofu apply`.
#
# DNS and custom hostnames live in separate `dns.tfvars` and
# `custom_hostnames.tfvars` files (see `envs/`) to keep `main.tfvars`
# focused on WAF, cache, and bot settings.
#
# Every feature is opt-out (defaults to true) for WAF, rate limit, and
# bot — a bare minimum zone definition just needs `zone_id` and
# `host_filter`. DNS and custom hostnames are off until you set
# `manage_dns` / `manage_custom_hostnames` and add records in the
# matching tfvars.

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone, WAF, Rulesets, Bot Management, and (if used) DNS / SSL Custom Hostname edit permissions."
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

    # Feature toggles (WAF, rate, bot default to true; cache rules default to true)
    waf_custom_rules_enabled   = optional(bool, true)
    rate_limit_catalog_enabled = optional(bool, true)
    bot_fight_mode               = optional(bool, true)
    site24x7_bot_skip            = optional(bool, true)
    cache_rules                  = optional(bool, true)

    # Rate-limit tuning per zone
    rate_limit_catalog = optional(object({
      requests_per_period = optional(number, 10)
      period              = optional(number, 10)
      block_duration      = optional(number, 10)
    }), {})

    # Hostnames: `extra_hosts` and `extra_cache_hosts` are merged (de-duplicated)
    # for the /catalog WAF rule and for per-host static cache rules. Use
    # `extra_cache_hosts` when you only need caching, not the challenge.
    extra_hosts       = optional(list(string), [])
    extra_cache_hosts = optional(list(string), [])
    extra_cache_paths   = optional(list(string), [])
    extra_skip_paths    = optional(list(string), [])

    cache_edge_ttl_hours  = optional(number, 2)
    cache_browser_ttl_min = optional(number, 30)

    homepage_cache_hosts = optional(list(string), [])

    homepage_cache_edge_ttl   = optional(number, 3600)
    homepage_cache_browser_ttl = optional(number, 300)

    cache_dynamic_pages = optional(bool, false)

    dynamic_cache_edge_ttl   = optional(number, 1800)
    dynamic_cache_browser_ttl = optional(number, 300)
    catalog_cache_edge_ttl   = optional(number, 600)
    catalog_cache_browser_ttl = optional(number, 120)

    validate_hosts = optional(list(string), [])

    # SAFETY: enable DNS / custom hostname resources only per zone
    manage_dns                 = optional(bool, false)
    manage_custom_hostnames   = optional(bool, false)
  }))
}

# ── DNS records (optional; see envs/<account>/dns.tfvars) ───────────

variable "dns_records" {
  description = "DNS records organized by zone key (must match a key in `var.zones`)"
  type = list(object({
    zone    = string
    records = list(object({
      name    = string
      type    = string
      content = string
      ttl     = optional(number, 1)
      proxied = optional(bool, false)
      comment = optional(string, "Managed by Terraform")
    }))
  }))
  default = []
  validation {
    condition = alltrue(flatten([
      for zone_obj in var.dns_records : [
        for record in zone_obj.records :
        length(lookup(record, "comment", "Managed by Terraform")) <= 100
      ]
    ]))
    error_message = "DNS record comments must be 100 characters or less."
  }
}

# ── Custom hostnames (optional; see custom_hostnames.tfvars) ────────

variable "custom_hostname_fallback_origins" {
  description = "Fallback origin per zone for custom hostnames. Only applied to zones with manage_custom_hostnames = true."
  type        = map(string)
  default     = {}
}

variable "custom_hostnames" {
  description = "Custom hostnames by zone key. Only applied to zones with manage_custom_hostnames = true."
  type = map(list(object({
    hostname     = string
    ssl_method   = optional(string, "http")
    ssl_wildcard = optional(bool, false)
  })))
  default = {}
}
