<div align="center">

# 🛤️ Golden Path

### A platform engineering portfolio where the delivery pipeline *is* the product.

The site isn't just a portfolio — it's the **output of the platform built to run it**.
Every commit travels the golden path: CI builds it, scanners vet it, containers ship it, GitOps deploys it, observability watches it.

![Astro](https://img.shields.io/badge/Astro-BC52EE?logo=astro&logoColor=white&style=for-the-badge)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white&style=for-the-badge)
![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white&style=for-the-badge)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white&style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white&style=for-the-badge)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?logo=argo&logoColor=white&style=for-the-badge)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white&style=for-the-badge)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white&style=for-the-badge)
![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white&style=for-the-badge)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?logo=trivy&logoColor=white&style=for-the-badge)

**Status:** 🟢 Phases 1–2 complete — the site is **live** at [http://40.119.232.45.sslip.io](http://40.119.232.45.sslip.io), deployed purely by GitOps.

</div>

---

## ✨ The Pitch

Most portfolios show *what* someone built. This one shows **how it runs**.

In platform engineering, the deliverable is rarely a feature — it's a **path** that makes delivery safe, fast, and boring. So this repo practices what it preaches: a static Astro site, deployed to Kubernetes on Azure through a complete internal-developer-platform-style pipeline, with every layer declared as code and every claim backed by a scanner or a live URL.

- 🧱 **Everything is code** — infra, config, manifests, and pipelines all live in this repo
- 🔁 **Nothing is manual** — the only human action is `git push`; ArgoCD does the rest
- 💸 **Everything is disposable** — `terraform destroy` between sessions keeps the bill at pocket-change level

---

## 🏗️ Architecture — live today

```
┌──────────┐   git push    ┌────────────────┐   build + scan   ┌────────────┐
│   You    │ ─────────────► │ GitHub Actions │ ───────────────► │    GHCR    │
└──────────┘                └────────────────┘                  └─────┬──────┘
                                                                     │ pull
   bump commit [skip ci]                                       ┌─────▼──────┐
   (image tag → new SHA)                                       │     AKS    │
┌──────────┐   GitOps sync  ┌────────────────┐    deploy       │ (1× B2s)   │
│  ArgoCD  │ ◄───────────── │   git (main)   │ ◄────────────── │  nginx app │
└──────────┘                └────────────────┘                 └─────┬──────┘
                                                                     │ ingress
                                                            ┌───────▼──────┐
                                                            │ 40.119.232.45│
                                                            │   .sslip.io  │
                                                            └──────────────┘
```

1. **Push** to `main` triggers GitHub Actions (path-filtered to `site/**`)
2. CI **builds** the Astro site (`npm ci && npm run check && npm run build`), **scans** the container with Trivy (HIGH/CRITICAL gates the push), and **pushes** to GHCR tagged `:<sha>` + `:latest`
3. `scripts/bump-image.sh` commits the new image tag into `k8s/deployment.yaml` with `[skip ci]`
4. **ArgoCD** (automated sync, prune, self-heal) detects the drift and rolls out the new image
5. The site is served via nginx-ingress at **http://40.119.232.45.sslip.io**

**Proof this loop works:** every commit in this repo since `276e224` was deployed by ArgoCD — including this README's host site, with zero manual `kubectl apply` for app changes.

---

## 🎯 Skills Showcased

| Domain | Where it lives | Status |
|---|---|---|
| ☁️ **Cloud (Azure)** | `infra/` — RG, VNet, AKS (1.36.2), Key Vault, OIDC issuer | ✅ live |
| 🧱 **IaC** | Terraform + remote state (Azure Storage, locked), `plan` before `apply` | ✅ live |
| 📦 **Containerization** | Multi-stage Dockerfile, `apk upgrade` for CVE patching, non-root, healthcheck | ✅ live |
| ☸️ **Kubernetes** | AKS + manifests: deployment (PSA-restricted-compliant), service, ingress, HPA | ✅ live |
| 🔄 **CI/CD** | GitHub Actions: build → check → scan → push → GitOps bump | ✅ live |
| 🔐 **Security** | Trivy clean (0 HIGH/CRITICAL), SHA-pinned actions, read-only deploy key, hardened nginx | ✅ live |
| 📈 **Observability** | kube-prometheus-stack, Blackbox probes, dashboards-as-code | ⏳ Phase 3 |

---

## 🧰 Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Frontend | **Astro 7** (static, TypeScript) | Ships zero JS by default; content-first; tiny container |
| Web server | **nginx 1.27-alpine** | Hardened headers, ~50 MB final image, non-root `USER nginx` |
| IaC | **Terraform** (azurerm ~> 4.0) | The cloud-agnostic standard; remote state + locking |
| Container registry | **GHCR** | Public images, native GitHub integration, free |
| Orchestration | **AKS** (Kubernetes 1.36.2, kubenet + Calico) | Managed control plane; Calico enables NetworkPolicy later |
| GitOps | **ArgoCD** | Pull-based sync, self-healing, automated prune |
| CI/CD | **GitHub Actions** | Free on public repos, path-filtered, workflow-as-code |
| Security | **Trivy** (SHA-pinned action) | Container scanning in the same pipeline |

---

## 📁 Repository Layout

```
golden-path/
├── site/                      # Astro static site (the portfolio)
│   ├── Dockerfile             # multi-stage: node build → nginx serve
│   ├── nginx.conf             # gzip, security headers, caching, non-root logs
│   └── src/pages/             # index, about, projects, blog, contact
├── infra/                     # Terraform — the Azure landing zone
│   ├── main.tf                # RG, VNet, AKS, Key Vault
│   ├── providers.tf           # azurerm + remote state backend
│   └── variables.tf           # region pinned (student-sub restriction)
├── k8s/                       # GitOps source of truth (ArgoCD-managed)
│   ├── deployment.yaml        # image tag bumped by CI
│   ├── service.yaml / hpa.yaml / ingress.yaml / namespace.yaml
│   ├── ingress-nginx-values.yaml   # AKS LB health-probe fix
│   └── argocd/application.yaml     # the GitOps Application
├── scripts/
│   ├── bootstrap-state.sh     # one-time: storage account for remote state
│   └── bump-image.sh          # CI → bump tag → commit [skip ci]
├── docs/                      # deep dives for interviewers
│   ├── architecture.md        # pipeline walkthrough + war stories
│   └── security.md            # threat model, controls, what's next
├── .github/workflows/ci.yml   # build → scan → push → bump
└── PLAN.md                    # the 5-phase implementation plan
```

---

## 🚀 Getting Started

> **Prerequisites:** `az` (logged in), `terraform`, `docker`, `kubectl`, `helm`, `node ≥ 22`, `gh`, `argocd`

```bash
# 1. Clone
git clone git@github.com:IlhaamGhiffari/golden-path.git && cd golden-path

# 2. One-time state bootstrap (storage account for Terraform remote state)
./scripts/bootstrap-state.sh

# 3. Provision the platform (RG → VNet → AKS → Key Vault)
cd infra && terraform init && terraform apply

# 4. Cluster access + ingress controller (AKS probe fix baked into values)
az aks get-credentials -g golden-path-rg -n golden-path-aks
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
  --create-namespace -f k8s/ingress-nginx-values.yaml

# 5. ArgoCD + repo access via scoped read-only SSH deploy key
helm install argocd argo/argo-cd -n argocd --create-namespace
argocd repo add git@github.com:IlhaamGhiffari/golden-path.git \
  --ssh-private-key-path ~/.ssh/gp-argocd-deploykey --insecure-ignore-host-key
kubectl apply -f k8s/argocd/application.yaml

# 6. Deploy: just push to main. ArgoCD does the rest. 😄
```

**Teardown (end of session — cost discipline):**
```bash
cd infra && terraform destroy -auto-approve
```

---

## 🔐 Security Posture

**In place today** (details in [docs/security.md](./docs/security.md)):

- **Trivy clean** — 0 HIGH/CRITICAL in CI; base image CVE-patched via `apk upgrade` in the Dockerfile
- **Supply-chain hardened** — trivy-action pinned to a commit SHA after its Mar-2026 compromise; all Actions version-pinned
- **No static secrets** — ArgoCD reads git via a **scoped read-only SSH deploy key** (revocable, not an account PAT); GHCR package is public so AKS pulls anonymously
- **Least privilege at runtime** — non-root (`101`), read-only root filesystem, all capabilities dropped, `seccomp: RuntimeDefault`, no privilege escalation
- **Hardened edge** — CSP, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy`, `server_tokens off`
- **State hygiene** — Terraform state only in Azure Storage (never committed)

**Next (Phase 3):** OIDC federation for Azure in CI, Pod Security Admission `restricted` enforcement, default-deny NetworkPolicy (Calico already enabled), IaC scanning (tfsec/Checkov), HSTS once TLS lands.

---

## 💰 Cost Efficiency

Running a Kubernetes cluster on Azure *responsibly*:

| Item | Left running 24/7 | With destroy discipline |
|---|---|---|
| AKS (1× B2s node) | ~$30 / mo | ~$3–5 / wk |
| Managed disk + storage | ~$2 / mo | only while running |
| Load balancer + public IP | ~$20 / mo | only while running |
| Registry (GHCR) / CI / monitoring | $0 | $0 |
| **Monthly total** | **~$55–60** ⚠️ | **~$15–25** |

**The point:** IaC makes platforms *disposable*. The final real bill gets published here as proof.

---

## 🗺️ Roadmap

- [x] Repo bootstrap, remote state strategy
- [x] Astro site + containerized build
- [x] CI/CD pipeline (build → scan → push → GitOps bump)
- [x] AKS provisioning + GitOps deploy (ArgoCD)
- [x] Public URL via ingress (sslip.io)
- [x] Documentation (this README + `docs/`)
- [ ] Observability stack (Prometheus/Grafana) + uptime probes
- [ ] Security hardening pass (OIDC, PSA, network policy, IaC scan)
- [ ] TLS via Cloudflare Tunnel
- [ ] Public release + demo video

---

## 📄 License

[MIT](./LICENSE) © 2026 [Muhaammad Ilhaam Ghiffari](https://github.com/IlhaamGhiffari)

<sub>Built to be deleted — `terraform destroy` is a feature, not a failure.</sub>
