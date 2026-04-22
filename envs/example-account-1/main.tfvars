# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   Cloudflare example
#
#   example-account-1  ·  main.tfvars
#   Per-account + zone config — replace placeholder IDs before apply.
#
# ════════════════════════════════════════════════════════════════════════════
#
#   `TF_VAR_cloudflare_api_token` in the environment; never commit tokens.
#   See `dns.tfvars` and `custom_hostnames.tfvars` in this directory.
#

account_name = "Example Repository Hosting"
account_id   = "REPLACE_WITH_YOUR_CLOUDFLARE_ACCOUNT_ID"

zones = {

  "example-repository-org" = {
    zone_id     = "00000000000000000000000000000000"
    host_filter = "example-repository.org"

    waf_custom_rules_enabled   = true
    rate_limit_catalog_enabled = true
    bot_fight_mode             = true
    site24x7_bot_skip          = true

    rate_limit_catalog = {
      requests_per_period = 10
      period              = 10
      block_duration      = 10
    }

    # Merged (de-duplicated) for /catalog WAF + per-host static cache.
    extra_hosts = [
      "digitalcollections.example-repository.org",
      "archive.example-repository.org",
    ]

    manage_dns              = false
    manage_custom_hostnames = false
  }

  # "second-example-org" = {
  #   zone_id     = "11111111111111111111111111111111"
  #   host_filter = "second-example.org"
  # }

}
