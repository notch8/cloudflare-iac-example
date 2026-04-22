# ── Example Account ────────────────────────────────────────────────
#
# This file shows the shape of a per-account tfvars. Replace the
# placeholder values below with your real Cloudflare account ID,
# zone IDs, and hostnames.
#
# Values starting with "REPLACE_" or "00000..." MUST be replaced
# before `tofu apply` — this file is intentionally non-functional as
# committed.

account_name = "Example Repository Hosting"
account_id   = "REPLACE_WITH_YOUR_CLOUDFLARE_ACCOUNT_ID"

# API token is set via the TF_VAR_cloudflare_api_token env var — do NOT
# put it in this file or commit it to git.

zones = {

  "example-repository-org" = {
    zone_id     = "00000000000000000000000000000000"
    host_filter = "example-repository.org"

    # All feature toggles default to true — shown here for clarity.
    waf_custom_rules_enabled   = true
    rate_limit_catalog_enabled = true
    bot_fight_mode             = true
    site24x7_bot_skip          = true

    # Rate-limit tuning. Defaults are 10 req / 10s / IP-per-colo, with
    # a 10-second block duration. Increase the period or lower the
    # requests_per_period if you still see scraping getting through.
    rate_limit_catalog = {
      requests_per_period = 10
      period              = 10
      block_duration      = 10
    }

    # Additional hostnames: merged into the /catalog WAF rule and
    # per-host static cache rules. Use `extra_cache_hosts` if you
    # want the same list split semantically in tfvars.
    extra_hosts = [
      "digitalcollections.example-repository.org",
      "archive.example-repository.org",
    ]

    # DNS and custom hostnames are opt-in; see dns.tfvars and
    # custom_hostnames.tfvars in this directory.
    manage_dns              = false
    manage_custom_hostnames = false
  }

  # Add more zones here as you roll out protection.
  #
  # "second-example-org" = {
  #   zone_id     = "11111111111111111111111111111111"
  #   host_filter = "second-example.org"
  # }

}
