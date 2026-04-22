# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   Cloudflare example
#
#   example-account-1  ·  custom_hostnames.tfvars
#   SSL for SaaS — needs manage_custom_hostnames + fallback per zone.
#
# ════════════════════════════════════════════════════════════════════════════
#
#   custom_hostname_fallback_origins = { "example-repository-org" = "fallback.example-repository.org" }
#   custom_hostnames = { "example-repository-org" = [ { hostname = "vanity.org" } ] }
#

custom_hostname_fallback_origins = {}
custom_hostnames                 = {}
