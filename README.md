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

**Status:** 🟡 Planning complete · Phase 1 implementation in progress — nothing deployed yet.
Sections marked **Target** describe the intended end state and become reality as each phase lands.

</div>

---

## ✨ The Pitch

Most portfolios show *what* someone built. This one shows **how it runs**.

In platform engineering, the deliverable is rarely a feature — it's a **path** that makes delivery safe, fast, and boring. So this repo practices what it preaches: a static Astro site, deployed to Kubernetes on Azure through a complete internal-developer-platform-style pipeline, with every layer declared as code and every claim backed by a scanner or a dashboard.

- 🧱 **Everything is code** — infra, config, dashboards, and pipelines all live in this repo
- 🔁 **Nothing is manual** — the only human action is `git push`
- 💸 **Everything is disposable** — `terraform destroy` between sessions keeps the monthly bill at pocket-change level

---

## 🏗️ Architecture *(Target)*

> **Target** — the intended end state. This pipeline is not deployed yet; it takes shape as the phases in the [plan](./PLAN.md) land.

```
┌──────────┐   git push    ┌────────────────┐   build + scan   ┌────────────┐
│   You    │ ─────────────► │ GitHub Actions │ ───────────────► │    GHCR    │
└──────────┘                └────────────────┘                  └─────┬──────┘
                                                                     │ pull
                                                                     ▼
┌──────────┐   GitOps sync  ┌────────────────┐    deploy     ┌────────────┐
│  ArgoCD  │ ◄───────────── │   git (main)   │ ◄──────────── │     AKS    │
└──────────┘                └────────────────┘               └─────┬──────┘
                                                                    │ scrape
                                                            ┌───────▼──────┐
                                                            │ Prometheus   │
                                                            │  +  Grafana  │
                                                            └──────────────┘
```

1. **Push** to `main` triggers GitHub Actions
2. CI **builds** the Astro site, **scans** it (Trivy), and **pushes** the container image to GHCR
3. A version-bump commit updates the image tag in the Kubernetes manifests
4. **ArgoCD** detects the drift and **syncs** the AKS cluster
5. **Prometheus + Grafana** scrape the cluster and blackbox-probe the site — uptime and latency, always visible

---

## 🎯 Skills Showcased *(Target)*

| Domain | Where it lives |
|---|---|
| ☁️ **Cloud (Azure)** | Terraform-provisioned landing zone: resource group, VNet, AKS, Key Vault |
| 🧱 **IaC** | Terraform with remote state in Azure Storage, `plan` gating CI |
| 📦 **Containerization** | Multi-stage Dockerfile, non-root runtime, healthcheck, SHA-pinned tags |
| ☸️ **Kubernetes** | AKS + manifests (deployment, service, ingress, HPA, network policies) |
| 🔄 **CI/CD** | GitHub Actions: lint → build → scan → push → GitOps sync |
| 🔐 **Security** | OIDC federation (zero static secrets), Trivy container + IaC scanning, restricted Pod Security, hardened nginx |
| 📈 **Observability** | kube-prometheus-stack, Blackbox uptime probes, dashboards as code |

---

## 🧰 Tech Stack *(Target)*

| Layer | Choice | Why |
|---|---|---|
| Frontend | **Astro** (static, TypeScript) | Ships zero JS by default; content-first; tiny container |
| Web server | **nginx** | Industry standard, hardened headers, ~50 MB final image |
| IaC | **Terraform** (azurerm) | The cloud-agnostic standard; remote state + locking |
| Container registry | **GHCR** | Free, public images, native GitHub integration |
| Orchestration | **AKS** (Kubernetes) | Managed control plane, the platform-engineering lingua franca |
| GitOps | **ArgoCD** | Pull-based sync, self-healing, the most recognized GitOps tool |
| CI/CD | **GitHub Actions** | Free on public repos, OIDC auth, workflow-as-code |
| Security | **Trivy** (+ tfsec/Checkov) | Container + IaC scanning in the same pipeline |
| Monitoring | **Prometheus + Grafana** | kube-prometheus-stack, ServiceMonitors, dashboards-as-code |

---

## 📁 Repository Layout

```
golden-path/
├── site/                      # Astro static site
│   ├── Dockerfile             # multi-stage: node build → nginx serve
│   └── nginx.conf             # gzip, security headers, caching
├── infra/                     # Terraform — the Azure landing zone
│   ├── main.tf                # RG, AKS, VNet, Key Vault
│   └── backend.tf             # state in Azure Storage (blob + lock)
├── k8s/                       # Kubernetes manifests (GitOps source of truth)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── network-policy.yaml
├── monitoring/                # dashboards & probes as code
├── .github/workflows/         # ci.yml, cd.yml
└── scripts/                   # bootstrap-state.sh, bump-image.sh
```

---

## 🚀 Getting Started

> **Prerequisites:** `az` (logged in), `terraform`, `docker`, `kubectl`, `helm`, `node ≥ 22`, `gh`

```bash
# 1. Clone
git clone git@github.com:IlhaamGhiffari/golden-path.git && cd golden-path

# 2. One-time state bootstrap (storage account for Terraform remote state)
./scripts/bootstrap-state.sh

# 3. Provision the platform (RG → VNet → AKS → Key Vault)
cd infra && terraform init && terraform apply

# 4. Deploy everything via GitOps
#    — push to main, ArgoCD does the rest. That's the whole point. 😄
```

---

## 🔐 Security Posture *(Target)*

- **No static secrets** — CI authenticates to Azure via OIDC federation (short-lived tokens, nothing stored); ArgoCD reads the repo via a scoped read-only SSH deploy key (or zero credentials once the repo is public) — never an account-level PAT
- **Scanning in the pipeline** — Trivy on every container image; tfsec/Checkov on every IaC change
- **Least privilege at runtime** — containers run as non-root with read-only root filesystem
- **Defense in depth on the cluster** — restricted Pod Security Admission, default-deny network policies
- **Hardened edge** — CSP, HSTS, nosniff, and friends at the nginx layer
- **State hygiene** — Terraform state never leaves Azure Storage and is never committed to git (it contains secrets)

---

## 💰 Cost Efficiency *(Target)*

Running a Kubernetes cluster on Azure *responsibly* — two scenarios:

| Item | Left running 24/7 | With destroy discipline |
|---|---|---|
| AKS (1× B2s node) | ~$30 / mo | ~$3–5 / wk |
| Managed disk + storage | ~$2 / mo | only while running |
| Load balancer + public IP | ~$20 / mo | only while running |
| Registry (GHCR) | $0 | $0 |
| CI/CD (GitHub Actions) | $0 | $0 |
| Monitoring (in-cluster) | $0 | $0 |
| **Monthly total** | **~$55–60** ⚠️ | **~$15–25** |

**The point:** IaC makes platforms *disposable*. The plan assumes destroy discipline — and the README will publish the final real bill as proof.

---

## 🗺️ Roadmap

- [x] Repo bootstrap, remote state strategy
- [ ] Astro site + containerized build
- [ ] CI/CD pipeline (build → scan → push)
- [ ] AKS provisioning + GitOps deploy
- [ ] Observability stack + uptime probes
- [ ] Security hardening pass
- [ ] Public release + demo video

---

## 📄 License

[MIT](./LICENSE) © 2026 [Muhaammad Ilhaam Ghiffari](https://github.com/IlhaamGhiffari)

<sub>Built to be deleted — `terraform destroy` is a feature, not a failure.</sub>
