# ── Custom hostnames (optional) ─────────────────────────────────────
# Set manage_custom_hostnames = true in main.tfvars for a zone, set a
# fallback origin hostname that exists in the zone, then list hostnames.
#
# custom_hostname_fallback_origins = { "example-repository-org" = "fallback.example-repository.org" }
# custom_hostnames = { "example-repository-org" = [ { hostname = "vanity.org" } ] }

custom_hostname_fallback_origins = {}
custom_hostnames                 = {}
