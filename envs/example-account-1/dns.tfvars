# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   Cloudflare example
#
#   example-account-1  ·  dns.tfvars
#   Optional DNS — requires manage_dns = true for each zone key below.
#
# ════════════════════════════════════════════════════════════════════════════
#
#   Example (commented):
#
#   dns_records = [
#     { zone = "example-repository-org", records = [
#       { name = "app.example.org", type = "CNAME", content = "origin.example.com", proxied = true }
#     ]}
#   ]
#

dns_records = []
