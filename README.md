# notch8-cloudflare-example

A minimal, runnable example of the Cloudflare Free Tier + OpenTofu edge protection pattern
Notch8 uses to stabilize multi-tenant [Hyku](https://hykucommons.org/) / [Hyrax](https://samvera.github.io/)
repository infrastructure under AI-driven scraping traffic.

This repo is the public companion to the *"From Whack-a-Mole to Edge Protection"* talk.

It is intentionally a **teaching example** — it highlights the core patterns we use in production
to protect expensive endpoints and reduce origin load, without the full complexity of our internal modules.

> [!NOTE]
> Written by the DevOps & Infrastructure team at [Notch8](https://www.notch8.com/).
> Released under the MIT license so you can copy, adapt, and share freely.

---

## The problem this solves

What we started seeing in production wasn't a traditional attack.

At first glance, it looked like normal traffic — but the pattern didn't match what we typically
see with DDoS attacks.

Scrapers were targeting **expensive endpoints**:

- `/catalog` (deep pagination, facet queries — Solr-intensive)
- `/concern/works/*` (multiple backend calls)
- IIIF manifests and thumbnails
- Download endpoints

These requests are not cheap. Every request consumes real resources — CPU, memory, and database
connections across shared infrastructure.

What made this worse:

- **20-60 second TTFB** on uncached requests
- **Unique query strings** to bypass caching
- Sustained pressure instead of short bursts

This wasn't a DDoS attack in the traditional sense —
but it had the **same impact**:

- Slow or unusable search
- Degraded public access
- Shared infrastructure instability across tenants

This repo demonstrates how we moved that load to the edge.

---

## What this shows

Cloudflare **free tier**-compatible rules, wired in one root module and designed to protect
high-cost application paths:

1. **WAF** (`waf_rules.tf`)
   - Skip rules for trusted traffic (monitoring, OAI-PMH, integrations)
   - Block rules for known bad probes
   - Managed Challenge on `/catalog` (with carve-outs for valid use cases like IIIF OCR)

2. **Rate limiting** (`rate_limiting.tf`)
   - Controls request bursts on expensive endpoints
   - Uses colo + IP to catch distributed scraping behavior

3. **Bot Fight Mode** (`bot_management.tf`)
   - Behavioral detection instead of relying on user-agent strings

4. **Caching strategy** (`cache_rules.tf`)
   - Anonymous traffic cached
   - Authenticated traffic bypasses cache
   - Reduces repeated origin hits for public content

5. **Optional DNS & custom hostnames**
   - Enables full edge control when needed

These patterns work together to reduce origin load and protect shared infrastructure.

---

## Architecture

User / Bot → Cloudflare (free tier)                → Origin (load balancer)   → Application
            ├─ WAF Skip rules  (trusted bots)        CNAME / A record           Hyku / Hyrax
            ├─ WAF Block rules (known-bad probes)                               Solr · Postgres · Fedora
            ├─ Managed Challenge on /catalog
            ├─ Rate limit per colo + IP
            └─ Bot Fight Mode (behavioral)

Every request is filtered, challenged, or blocked at the edge before it consumes
origin CPU / memory / DB connections.

Instead of reacting at the application layer, we intercept expensive traffic at the edge —
where it is significantly cheaper to evaluate and control.

Shared cluster resources stay stable because one noisy tenant no longer degrades everyone else.

---

## Repo layout

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

---

## Quick start

1. **Prerequisites**
   - OpenTofu ≥ 1.6 (or Terraform ≥ 1.6)
   - A Cloudflare account with at least one zone on the Free plan
   - An S3 bucket for state, or switch providers.tf to a local backend

   For more details on managing Cloudflare with Infrastructure as Code:
   https://developers.cloudflare.com/workers/platform/infrastructure-as-code/

2. **Create a scoped Cloudflare API token**

   Required permissions:
   - Zone: Read
   - Zone WAF: Edit
   - Zone Settings: Edit
   - Bot Management: Edit

   Add DNS + SSL permissions if using those features.

3. **Copy and edit the example tfvars**

   cp -r envs/example-account-1 envs/my-account

4. **Apply**

   export TF_VAR_cloudflare_api_token='your-api-token'
   tofu init
   tofu workspace new my-account
   VARFILES="-var-file=envs/my-account/main.tfvars -var-file=envs/my-account/dns.tfvars -var-file=envs/my-account/custom_hostnames.tfvars"
   tofu plan  $VARFILES
   tofu apply $VARFILES

---

## Gotchas we learned the hard way

1. Allow-list legitimate bots explicitly
2. Behavioral detection beats user-agent blocking
3. Rate-limit per colo + IP
4. Use contains instead of exact match for bad paths
5. Carve out background fetch endpoints
6. Free tier cache rule limits exist
7. Always review Terraform provider changes

---

## Why free tier

This approach prioritizes moving compute to the edge, where decisions are cheaper and faster,
instead of scaling origin infrastructure to absorb avoidable load.

Everything in this example runs on Cloudflare's Free plan — meaning edge protection can be added
with zero platform cost.

---

## License

MIT — see LICENSE.

---

## Contributing / questions

Issues and PRs welcome.

---

## Want to talk it through?

Email: support@notch8.com
https://www.notch8.com/

If you came here from a talk or discussion, we'd love to hear what's working (or not).

---

Maintained by Notch8 — DevOps & Infrastructure team.