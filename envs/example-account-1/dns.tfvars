# ── DNS records (optional) ─────────────────────────────────────────
# Set manage_dns = true for a zone in main.tfvars, then add a block here
# with zone = "<that zone key>".
#
# Example (commented; un-comment after enabling manage_dns and fixing IDs):
#
# dns_records = [
#   {
#     zone = "example-repository-org"
#     records = [
#       {
#         name    = "app.example-repository.org"
#         type    = "CNAME"
#         content = "origin.example.com"
#         proxied = true
#       }
#     ]
#   }
# ]

dns_records = []
