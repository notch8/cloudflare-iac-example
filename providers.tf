# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   OpenTofu   ·   Cloudflare
#
#   Provider & backend
#   Wire the Cloudflare provider; point `backend` at durable shared state.
#
# ════════════════════════════════════════════════════════════════════════════
#
#   API token: `TF_VAR_cloudflare_api_token` (e.g. from 1Password at apply time —
#   no secrets in tfvars or git). Swap the S3 example for local / GCS / HTTP, etc.
#

terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # ---------------------------------------------------------------------------
  #  Backend — replace with your org’s state (S3 example below).
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket = "your-opentofu-state-bucket"
  #   key    = "cloudflare-example/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
