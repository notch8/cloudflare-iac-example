# ── Bot Fight Mode ──────────────────────────────────────────────────
#
# Enables Cloudflare's built-in behavioral bot detection. Available on
# the Free plan. Catches scrapers by behavior (request patterns, TLS
# fingerprints, JS execution) rather than user-agent string — which
# is the right call, because UA strings are trivially spoofed.
#
# The `enable_js` flag injects Cloudflare's JS challenge into pages
# served to suspected bots; real browsers solve it transparently.

resource "cloudflare_bot_management" "bot_fight_mode" {
  for_each = { for k, v in var.zones : k => v if v.bot_fight_mode }

  zone_id    = each.value.zone_id
  fight_mode = true
  enable_js  = true
}
