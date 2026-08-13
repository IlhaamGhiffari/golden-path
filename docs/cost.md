# Cost — the honest bill

The whole point of the destroy-discipline strategy: **IaC makes platforms disposable**, so the
portfolio runs on pocket change. Here's the actual accounting.

## What things cost

| Item | Unit | Notes |
|---|---|---|
| AKS control plane | $0 | free with 1 node pool |
| Node `Standard_B2ms` (8GB) | ~$0.088/hr | was B2s (~$0.044/hr) — upgraded after war story #13 (4GB couldn't hold the stack) |
| Managed disk (node OS) | ~$1/mo | ~30GB Standard SSD |
| Load balancer (Standard) | ~$0.025/hr | created by the ingress-nginx service |
| Public IP | ~$0.005/hr | Standard SKU, static |
| Key Vault (Standard) | ~$0.25/mo | free tier-ish |
| Terraform state storage | <$0.05/mo | Standard_LRS blob, ~KB |
| GHCR + GitHub Actions | $0 | public repo / free minutes |
| Domain `ilhaamghiffari.tech` | ~$5-10/yr | get.tech promo (out-of-pocket, not Azure) |
| Let's Encrypt certs | $0 | cert-manager, auto-renew |

## Real running cost per session

A work session that keeps the cluster up ~6-8h and then runs `terraform destroy`:

| Scenario | Cost |
|---|---|
| B2s node, one session | ~$0.40-0.60 |
| B2ms node, one session | ~$0.70-0.95 |
| Left running 24/7 (the anti-pattern) | ~$60-70/mo |

## Budget envelope

- Azure for Students credit: **$100** (expires **Sep 13 2026**)
- Planned spend: **$20-35 total** across the project with destroy discipline
- **Rule:** `terraform destroy` at the end of every session; `az aks stop` for same-day pauses
- **Actual so far (Aug 14):** **$0.78 spent** — see proof in `docs/evidence/`:
  - [billing-summary.png](evidence/billing-summary.png) — $99.22 remaining
  - [billing-cost-analysis.png](evidence/billing-cost-analysis.png) — per-service breakdown (Virtual Network $0.51, VMs $0.17, Storage $0.10)
  - [billing-credits.png](evidence/billing-credits.png) — credit active until 2026-09-13

## Why this is a feature, not a bug

Destroy-and-rebuild in ~25 minutes from the repo is the *demonstration*: the platform is fully
reproducible from code, so running it costs what you decide it costs. That's the same discipline
a platform team applies to non-production environments — scaled down to a student budget.
