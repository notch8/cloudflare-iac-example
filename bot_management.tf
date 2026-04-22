# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   OpenTofu   ·   Cloudflare
#
#   Bot Fight Mode
#   Behavioral detection (TLS, patterns, JS) — not user-agent string matching
#
# ════════════════════════════════════════════════════════════════════════════
#
#   Free tier. `enable_js` serves a challenge to suspected bots; real browsers
#   complete it without friction.
#

resource "cloudflare_bot_management" "bot_fight_mode" {
  for_each = { for k, v in var.zones : k => v if v.bot_fight_mode }

  zone_id    = each.value.zone_id
  fight_mode = true
  enable_js  = true
}
