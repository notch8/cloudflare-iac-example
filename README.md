<div align="center">

# Notch8 · Cloudflare edge protection

### Cloudflare · free tier · Hyku & Hyrax-ready

<a href="https://github.com/notch8/cloudflare-iac-example/releases/tag/fedora-showcase-april-2026" title="From Whack-a-Mole to Edge Protection — slides & resources">
  <img src="https://github.com/notch8/cloudflare-iac-example/releases/download/fedora-showcase-april-2026/n8-from-whack-a-mole-to-edge-protection.png" alt="From Whack-a-Mole to Edge Protection — title slide" width="680" />
</a>

Public reference for the patterns we use to keep multi-tenant repository traffic stable under AI-driven scraping.

[Notch8](https://www.notch8.com/) · [Hyku](https://hykucommons.org/) · [Hyrax](https://samvera.github.io/) · *From Whack-a-Mole to Edge Protection* — [Talk slides](https://github.com/notch8/cloudflare-iac-example/releases/tag/fedora-showcase-april-2026)

</div>

---

## Contents

- [Talk slides](#talk-slides)
- [The problem](#the-problem-this-solves)
- [Module contents](#module-contents)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Lessons from production](#lessons-from-production)
- [License & contact](#license--contact)

---

## Talk slides

**From Whack-a-Mole to Edge Protection.** The **[latest release: fedora-showcase-april-2026](https://github.com/notch8/cloudflare-iac-example/releases/tag/fedora-showcase-april-2026)** includes the presentation as a release asset. The banner above is the talk's title slide.

---

## The problem this solves

In production, the painful traffic often **looks** normal. Scrapers target expensive paths (`/catalog`, works, IIIF, downloads) with **long TTFB** and **unique query strings** so caching does not help. That behaves like a slow DDoS: Solr, app servers, and shared tenants all suffer.

This module moves **filtering, challenge, and cache decisions to the edge** so origin work stays bounded.

---

## Module contents

| Layer | File | Role |
|--------|------|------|
| WAF | `waf_rules.tf` | Skips (bots + paths), blocks probes, challenge on `/catalog` (IIIF carve-out) |
| Rate | `rate_limiting.tf` | `/catalog` throttling, colo + IP |
| Bot | `bot_management.tf` | Bot Fight Mode — behavior, not UA strings |
| Cache | `cache_rules.tf` | Static, optional homepages, opt-in dynamic tier, session bypass |
| DNS | `dns_records.tf` | Optional, `manage_dns` + `dns.tfvars` |
| SaaS hostnames | `custom_hostnames.tf` | Optional, `manage_custom_hostnames` + `custom_hostnames.tfvars` |
| I/O | `outputs.tf` | Zone summary + resource counts |
| Config | `variables.tf`, `providers.tf` | Schema, provider, state backend hook |

**Teaching scope:** this repo is the **Terraform root** and env tfvars. CI, workspaces-as-a-service, and secret workflows stay in our private ops repo.

> [!NOTE]
> **License:** MIT — copy and adapt. **Maintainer:** [Notch8](https://www.notch8.com/) Infrastructure team.

---

## Architecture

```text
                    ┌─────────────────────────────────────┐
  User / bot        │  Cloudflare (Free)                 │         Origin
  ───────────────►  │  WAF skip · block · challenge       │  ──►   LB / app
                    │  Rate limit  ·  cache  ·  bot        │         Hyku / Hyrax
                    └─────────────────────────────────────┘
```

Requests are evaluated at the **edge** before they consume app CPU, DB, and Solr. Optional DNS and custom hostnames keep control in one place when you are ready.

---

## Repository layout

```text
.
├── providers.tf
├── variables.tf
├── waf_rules.tf
├── rate_limiting.tf
├── bot_management.tf
├── cache_rules.tf
├── dns_records.tf
├── custom_hostnames.tf
├── outputs.tf
└── envs/
    ├── example-account-1/
    │   ├── main.tfvars
    │   ├── dns.tfvars
    │   └── custom_hostnames.tfvars
    └── example-account-2/
        ├── main.tfvars
        ├── dns.tfvars
        └── custom_hostnames.tfvars
```

---

## Quick start

**Prerequisites**

- [OpenTofu](https://opentofu.org/) ≥ 1.6 (or Terraform ≥ 1.6)
- A Cloudflare zone on the **Free** plan
- Remote state (S3 or adjust `providers.tf`) for team use
- [IaC overview](https://developers.cloudflare.com/workers/platform/infrastructure-as-code/) (Cloudflare)

**API token (minimum for WAF + bot + cache)**

| Scope | Permission |
|--------|------------|
| Zone | Zone — Read |
| Zone | WAF — Edit |
| Zone | Zone Settings — Edit |
| Zone | Bot Management — Edit |

Add **DNS** and **SSL / Custom hostnames** if you use those features.

**Configure and apply**

```bash
cp -r envs/example-account-1 envs/my-account
# Edit envs/my-account/main.tfvars (and dns / custom hostnames as needed)

export TF_VAR_cloudflare_api_token='your-api-token'
tofu init
tofu workspace new my-account

VARFILES="-var-file=envs/my-account/main.tfvars \
  -var-file=envs/my-account/dns.tfvars \
  -var-file=envs/my-account/custom_hostnames.tfvars"

tofu plan  $VARFILES
tofu apply $VARFILES
```

---

## Lessons from production

1. **Allow-list the good bots** (monitoring, OAI-PMH) or harvesters and feeds break.
2. **Prefer behavior** (Bot Fight, challenges) over blocking user agents — UAs are spoofed.
3. **Rate limit on colo + IP** to catch distributed scrapers at the edge.
4. **Use `contains` (not only exact match)** for bad paths (e.g. `//xmlrpc.php`).
5. **Carve out** endpoints that do background fetches (e.g. IIIF OCR search) from interactive challenges.
6. **Free tier: 10 cache rules per zone** — plan the rule budget.
7. **Pin the provider** and read changelogs before upgrades.

**Why free tier:** edge compute for policy is cheaper than scaling origin to absorb the same load. This stack targets **$0** Cloudflare fees for the controls above.

---

## License & contact

- **License:** [MIT](LICENSE)
- **Issues & PRs:** welcome
- **Notch8:** [notch8.com](https://www.notch8.com/) · [support@notch8.com](mailto:support@notch8.com)

---

<div align="center">

**Notch8** · Infrastructure

*Libraries, archives, universities — and the platforms that serve them.*

</div>
