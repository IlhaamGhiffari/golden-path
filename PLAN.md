# Golden Path — Platform Engineering Portfolio Implementation Plan

> **For Hermes:** Execute this plan phase-by-phase, verifying each phase before moving on.

**Goal:** A platform engineering portfolio where the *delivery pipeline itself* is the portfolio — an Astro static site deployed to Azure via a full golden path: IaC → containerization → Kubernetes → GitOps → CI/CD → security scanning → observability.

**Architecture:** Push to `main` triggers GitHub Actions. CI builds the Astro site, scans it (Trivy), pushes the image to GHCR. A version bump commit updates the K8s manifests; ArgoCD detects the drift and syncs the AKS cluster. Prometheus + Grafana (kube-prometheus-stack) monitor the cluster and the site. Everything (infra included) is declared in Terraform, state in Azure Storage.

**Tech Stack:** Astro (static, TypeScript) · Docker + nginx · Terraform (Azure) · AKS · ArgoCD (GitOps) · GitHub Actions (CI/CD, OIDC auth) · GHCR · Prometheus/Grafana · Trivy

---

## Context & Constraints

- **Azure student credit: $100, expires in ~5 weeks** (capped — no over-billing risk, but the clock is real)
- Skills to showcase: **cloud, IaC, containerization, k8s, CI/CD, security, monitoring**
- Solo project; repo name: `golden-path` (chosen)
- Primary audience: hiring managers / platform engineering interviewers
- Cost strategy: **pay for uptime, not ownership** — `terraform destroy` between work sessions

## Domain → Component Map

| Showcase skill | Where it lives in the repo |
|---|---|
| ☁️ Cloud (Azure) | `infra/` — Terraform: RG, AKS, VNet, Key Vault, storage (state) |
| 🧱 IaC | Terraform + remote state + `terraform plan` gating CI |
| 📦 Containerization | Multi-stage Dockerfile, non-root, healthcheck, SHA tagging |
| ☸️ Kubernetes | AKS + manifests: deployment, service, ingress, HPA, netpol |
| 🔄 CI/CD | GitHub Actions: lint → build → scan → push → GitOps sync |
| 🔐 Security | OIDC (no static secrets), Trivy (container + IaC), restricted PSA, non-root, nginx security headers |
| 📈 Monitoring | kube-prometheus-stack, Blackbox uptime, Grafana dashboards-as-code |

## Target Repo Layout

```
golden-path/
├── site/                      # Astro static site (portfolio content)
│   ├── Dockerfile             # multi-stage: node build → nginx serve
│   └── nginx.conf             # gzip, security headers, caching
├── infra/                     # Terraform — cloud + IaC
│   ├── providers.tf           # azurerm + GitHub OIDC
│   ├── main.tf                # RG, AKS, VNet, Key Vault
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf             # state in Azure Storage (blob + lock)
├── k8s/
│   ├── namespace.yaml
│   ├── deployment.yaml        # app (image from GHCR)
│   ├── service.yaml
│   ├── ingress.yaml           # nginx ingress controller
│   ├── hpa.yaml               # horizontal pod autoscaler
│   └── network-policy.yaml    # deny-by-default
├── monitoring/
│   ├── grafana-dashboards/    # dashboard JSONs as code
│   └── blackbox.yaml          # uptime probe config
├── .github/workflows/
│   ├── ci.yml                 # build + trivy scan + push to GHCR
│   └── cd.yml                 # terraform plan/apply + image bump
├── scripts/
│   ├── bootstrap-state.sh     # one-time: storage account for state
│   └── bump-image.sh          # update image tag in manifests, commit
├── .gitignore
└── README.md                  # the real resume — documents the pipeline
```

## Budget & Cost Control

| Component | Strategy | Est. cost |
|---|---|---|
| AKS 1× B2s node | Run only during work sessions; destroy between | ~$3–5/wk |
| Registry | GHCR (free, public repo) | $0 |
| Key Vault (Standard) | Free tier | $0 |
| Disk/storage/public IP | Destroyed with cluster | ~$1–2/wk |
| Monitoring | In-cluster kube-prometheus-stack + Grafana Cloud free tier (optional) | $0 |
| CI/CD | GitHub Actions, free on public repos | $0 |
| **Total 5 weeks** | | **~$20–35** (conservative: ~$55–60/mo if left running 24/7 — the estimate assumes destroy discipline) |

**Rules:** destroy cluster at end of every session (`terraform destroy`); set calendar reminder 3 days before credit expiry; screenshot billing page for README flex.

---

# Phase 0 — Prerequisites (Day 0)

**Objective:** Working local toolchain + verified Azure/GitHub access.

**Files:** none (env setup only)

1. Verify tools:
   ```bash
   az --version && terraform --version && docker --version \
     && kubectl version --client && helm version && gh --version && node --version
   ```
   Expected: all print versions. Install any missing (`brew install azure-cli terraform kubectl helm gh`, Node 22 via `nvm install 22`).

2. Azure login + confirm student subscription:
   ```bash
   az login
   az account list --output table
   az account set --subscription "<Azure for Students>"
   ```
   Verify: subscription shows the $100 credit remaining.

3. GitHub auth:
   ```bash
   gh auth login        # HTTPS + browser
   gh repo create golden-path --private --source . --push   # (after git init, Phase 1)
   ```
   Note: repo can be made public later once content exists.

4. Export Azure identity for Terraform:
   ```bash
   az account show --query "{subscriptionId:id, tenantId:tenantId}" -o json
   export ARM_SUBSCRIPTION_ID=<id>   # add to ~/.zshrc
   ```

**Verify:** all version commands succeed; `az account show` returns the student subscription; `gh auth status` shows logged in.

---

# Phase 1 — Site + Container + CI + Terraform Basics (Week 1)

**Objective:** The Astro site builds, scans clean, and ships as a container. Terraform bootstrap + state ready. **No cluster yet — cost ≈ $1.**

### Task 1.1 — Init repo + git

```bash
cd ~/Documents/Personal/Programming/platform-engineering/golden-path
git init -b main
```

Add `.gitignore` (node_modules, dist, .terraform, *.tfstate*, .env). First commit:
```bash
git add . && git commit -m "chore: init golden-path repo"
```

### Task 1.2 — Scaffold Astro site

```bash
npm create astro@latest site -- --template minimal --typescript strict --git false
cd site && npm install
```

Set `output: 'static'` (default) in `site/astro.config.mjs`. Content language: **EN** (hiring-manager audience); hero text-only, **no photo**. Add content: `src/pages/index.astro` (hero: name, one-liner, the 7 showcased skills), `about.astro`, `projects.astro` (cards linking to the future demo + GitHub), `blog.astro` stub, `contact.astro`.

**Verify:** `npm run dev` → site at http://localhost:4321; `npm run build` exits 0 and produces `site/dist/`.

Commit: `feat: scaffold astro portfolio site`.

### Task 1.3 — Dockerfile + nginx config

- Create `site/Dockerfile` — two-stage: `node:22-alpine` build (`npm ci`, `npm run build`) → `nginx:1.27-alpine`, copy `dist/`, non-root `USER nginx`, `HEALTHCHECK` via wget.
- Create `site/nginx.conf` — gzip, security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, CSP), cache static assets.
- Create `site/.dockerignore` — node_modules, dist, .git, .env.

**Verify locally:**
```bash
docker build -t golden-path:dev site/
docker run -p 8080:80 golden-path:dev
curl -sI http://localhost:8080/ | grep -i "x-content-type\|server"
docker exec <container> wget -qO- http://localhost/ | head
```
Expected: 200s, security headers present, healthcheck passing (`docker inspect --format='{{.State.Health.Status}}'`).

Commit: `feat: containerize site with nginx`.

### Task 1.4 — Trivy scan locally

```bash
brew install trivy
trivy image --severity HIGH,CRITICAL golden-path:dev
```
Expected: no HIGH/CRITICAL (alpine + nginx are lean; if findings appear, pin/upgrade base images).

### Task 1.5 — CI workflow (build → scan → push)

Create `.github/workflows/ci.yml`:
- trigger: `pull_request`, `push` to `main` (path: `site/**`)
- jobs: `build` — setup-node 22, `npm ci`, `npm run build`, `astro check`
- `scan` — `aquasecurity/trivy-action@master` with `image-ref` from build
- `push` — `docker/login-action@v3` to `ghcr.io`, `docker/build-push-action@v6` tagged `ghcr.io/<user>/golden-path:<sha>` + `:latest`

Commit: `ci: add build, scan, push pipeline`.

**Verify:** push → Actions runs → image appears at https://github.com/users/<user>/packages (make package public so AKS can pull without auth).

### Task 1.6 — Terraform bootstrap (state)

- Create `scripts/bootstrap-state.sh`:
  ```bash
  az group create --name golden-path-state-rg --location eastus
  az storage account create --name gpstate$(openssl rand -hex 3) \
    --resource-group golden-path-state-rg --sku Standard_LRS
  az storage container create --name tfstate --account-name <acct>
  ```
- Create `infra/backend.tf` (azurerm backend with the created account), `infra/providers.tf` (azurerm, `features {}`).
- `infra/main.tf` minimal for now: resource group `golden-path-rg` only.

```bash
cd infra && terraform init && terraform plan && terraform apply
```
Expected: RG created; `terraform.tfstate` now remote (check storage container).

Commit: `feat: terraform bootstrap with remote state`.

**Phase 1 done when:** site builds+scans clean in CI, image in GHCR, Terraform applies with remote state. **Cost: ~$1.**

---

# Phase 2 — The K8s Week: AKS + GitOps (Week 2)

**Objective:** Cluster up, site running on AKS, ArgoCD doing GitOps. **Cost: ~$10–15 (cluster running while you learn; destroy nightly if possible).**

### Task 2.1 — Terraform AKS

Extend `infra/main.tf`:
- VNet + subnet (address space `10.0.0.0/16`)
- AKS: `kubernetes_version` latest stable, system node pool `Standard_B2s` × **1** (min count 1), `enable_auto_scaling = false`, `network_profile` kubenet (simpler/cheaper), RBAC on, `oidc_issuer_enabled = true` (future workload identity), `azure_policy_enabled = true` (extra security cred)
- Key Vault (Standard — free): store nothing critical yet, exists for the story + future use
- outputs: `cluster_name`, `resource_group_name`, `kubeconfig` (sensitive)

```bash
cd infra && terraform plan && terraform apply   # ~10-15 min for cluster
```
Expected: `Apply complete`; cluster shows in Azure portal.

Commit: `feat: provision AKS cluster via terraform`.

### Task 2.2 — Connect kubectl + deploy manifests

```bash
az aks get-credentials -g golden-path-rg -n golden-path-aks
kubectl get nodes   # 1 node, Ready
```

Create `k8s/` manifests: `namespace.yaml` (`portfolio`), `deployment.yaml` (image `ghcr.io/<user>/golden-path:<sha>`, replicas 2, resource requests/limits, `securityContext` readOnlyRootFilesystem), `service.yaml` (ClusterIP 80), `hpa.yaml` (cpu 70%, min 2 max 6).

```bash
kubectl apply -f k8s/namespace.yaml -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/hpa.yaml
kubectl -n portfolio get pods   # Running
kubectl -n portfolio port-forward svc/golden-path 8080:80
curl -sI http://localhost:8080/   # 200
```

Commit: `feat: add kubernetes manifests`.

### Task 2.3 — Ingress + public access

- Install nginx ingress controller: `helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace -f k8s/ingress-nginx-values.yaml` (or via Terraform `helm_release` — preferred, keeps everything IaC; requires `helm` provider in `infra/`).
  - **AKS gotcha (fixed in `k8s/ingress-nginx-values.yaml`):** the default Azure LB health probe is HTTP GET `/` without a Host header; ingress-nginx answers 404 → node unhealthy → public URL times out. Set `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz`.
- `k8s/ingress.yaml` → host `<your-ip>.sslip.io` (or custom domain if bought; see Open Questions). Wait for LB: `kubectl -n ingress-nginx get svc ingress-nginx-controller -w` (get EXTERNAL-IP).
- Apply ingress, curl the public URL from outside.

Commit: `feat: expose site via ingress`.

### Task 2.4 — ArgoCD GitOps

```bash
helm install argocd argo/argo-cd -n argocd --create-namespace
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward -n argocd svc/argocd-server 8080:443   # login admin
```

- Create `k8s/argocd/application.yaml` — Application `golden-path`, source = this git repo path `k8s/`, destination `portfolio` namespace, `automated: prune: true, selfHeal: true`.
- ArgoCD needs repo read access — **not** an account-level PAT (a static secret tied to your account; it would break the "no static secrets" story). Instead:
  - Repo is **public** → zero credentials needed: `argocd repo add https://github.com/<user>/golden-path`
  - Repo stays **private** → scoped read-only **SSH deploy key** (revocable, not tied to an account): `argocd repo add git@github.com:<user>/golden-path.git --ssh-private-key-file <deploy-key>`
- Apply Application; ArgoCD syncs deployment from git.

**Verify GitOps works:** change image tag in `k8s/deployment.yaml`, commit+push → ArgoCD auto-syncs within ~3 min (`argocd app get golden-path` shows Synced/Healthy; `kubectl get pods` shows new revision rolling).

Commit: `feat: add argocd gitops application` + `ci: add image bump step`.

### Task 2.5 — Image-bump automation

`scripts/bump-image.sh`: on CI success, `sed` the image tag in `k8s/deployment.yaml` to the new SHA and commit → triggers ArgoCD sync. Wire into `ci.yml` (`push` job tail, needs `build`), or a small `cd.yml`. This completes the loop: **push → CI → new image → git bump → ArgoCD deploys.**

**Loop-safety (critical):**
- The bump commit message **must** contain `[skip ci]` — otherwise the bump commit re-triggers CI → infinite loop.
- Add `concurrency: { group: deploy, cancel-in-progress: false }` to the workflow so bump runs serialize instead of racing each other.
- Branch protection note: under a protected `main`, the automated bump push needs an explicit allowance (bypass for the workflow's git identity, or a merge queue). Decide and document whichever you choose — in the README, not just the plan.

**Verify:** full pipeline from empty: `git push` → Actions green → ArgoCD Healthy → public URL serves new content.

**Phase 2 done when:** site live at a public URL via AKS, deployed purely by GitOps. **Destroy nightly when not learning: `terraform destroy` (or `az aks stop` for same-day resumes).**

---

# Phase 3 — Monitoring + Security (Week 3)

**Objective:** Observability you can demo, security you can defend in interviews. **Cost: ~$5.**

### Task 3.1 — kube-prometheus-stack

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```
- Login admin/`kubectl get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d`
- Import Node Exporter Full dashboard (ID 1860) + Kubernetes cluster dashboards; save JSON exports into `monitoring/grafana-dashboards/` (dashboards-as-code).
- Add a ServiceMonitor for the portfolio namespace so app metrics (nginx `stub_status` or Astro request logs) are scraped.

Commit: `feat: add prometheus+grafana stack` + `feat: export dashboards as code`.

### Task 3.2 — Blackbox uptime

- `monitoring/blackbox.yaml` — probe `https://<your-url>` every 60s.
- `helm install blackbox-exporter prometheus-community/prometheus-blackbox-exporter -n monitoring -f monitoring/blackbox.yaml`
- Grafana dashboard "Blackbox Exporter" (ID 7587): uptime % + latency for your site.

Commit: `feat: add blackbox uptime monitoring`.

### Task 3.3 — Security hardening (the interview gold)

1. **OIDC in CI (no static secrets):** in `cd.yml`, `azure/login@v2` with `auth-type: OIDC` + federated credential on a service principal scoped to `golden-path-rg`. Delete any client-secret usage. *(Document the federated credential setup in README.)*
2. **IaC scanning:** add `aquasecurity/tfsec` or `checkov` job to `ci.yml` scanning `infra/` (or `terraform plan` + `tfsec` in `cd.yml`).
3. **Pod Security:** `kubectl label ns portfolio pod-security.kubernetes.io/enforce=restricted` (or Kyverno policy — optional add-on) — proves you know admission control.
4. **Network policy:** `k8s/network-policy.yaml` — default-deny, allow ingress-nginx → app, app → DNS/egress. Apply, verify site still serves.
5. **nginx headers** already shipped in Phase 1 (CSP, HSTS, nosniff).
6. Optional: `trivy fs` on the whole repo (misconfig scan) as a scheduled workflow (weekly).

Commit per item. **Verify each:** run the workflow and show green scans; `kubectl get netpol`; attempt `kubectl exec` into pod (denied by restricted PSA — screenshot the denial, it's a great story).

### Task 3.4 — Grafana Cloud free tier (optional, survives cluster death)

- Sign up Grafana Cloud free; send Prometheus metrics via remote_write; dashboards keep working even after `terraform destroy`. Strong "managed vs self-hosted" talking point.

**Phase 3 done when:** dashboards live, blackbox shows uptime, OIDC CI green, PSA + netpol enforced. **Cost: ~$5.**

---

# Phase 4 — Polish & Evidence (Week 4)

**Objective:** Make the portfolio *interviewable*. **Cost: ~$5.**

### Task 4.1 — README.md (the real resume)
Sections: architecture diagram (ASCII), the 7-domain mapping table, quickstart (`make up` style: bootstrap-state → terraform apply → helm install), pipeline walkthrough, cost breakdown (screenshot billing page), "what I'd do differently". Aim: a platform engineer should finish it and want to interview you.

### Task 4.2 — Site content

- Projects section (EN): this repo as flagship + Aceh Resilience Monitor (Top 20 Datathon AI Impact Challenge 2026) + hydrology debit andalan project (commercial).
- Blog stub → 2 short posts: "Deploying my portfolio like a platform product" and "Why GitOps" (screenshots from ArgoCD UI).
- Link the live URL prominently.

### Task 4.3 — Evidence pack

- Screenshots: ArgoCD UI (Synced/Healthy), Grafana dashboards, GitHub Actions green runs, Trivy clean report.
- Record 3–5 min demo video (QuickTime/OBS): push a commit → watch CI → watch ArgoCD sync → show dashboards. Save to repo `docs/demo.mp4` + YouTube unlisted link.
- `docs/` folder: architecture.md, security.md, cost.md — deep dives for interviewers.

### Task 4.4 — Make repo public

`gh repo edit --visibility public`. Update repo description (the golden-path one-liner from planning).

**DONE (2026-08-14):** repo public at `https://github.com/IlhaamGhiffari/golden-path`; secret scanning + push protection + dependabot security updates enabled; description set; README roadmap updated. Remaining: demo video (4.3).

**Phase 4 done when:** README + docs + video + screenshots all in repo; repo public; site content complete.

---

# Phase 5 — Endgame & Survivability (Week 5)

**Objective:** The portfolio outlives the credit. **Cost: $0.**

### Task 5.1 — Graceful teardown

1. Screenshot everything (billing, dashboards, ArgoCD).
2. Export final dashboards JSON → repo.
3. ```bash
   cd infra && terraform destroy -auto-approve
   az group delete -n golden-path-state-rg -y   # last: kills state too
   ```
4. **Never commit `terraform.tfstate`** — it contains secrets (storage account keys, kubeconfigs, passwords). Preserve evidence with redacted screenshots, `terraform output` values, or sanitized snippets only.

### Task 5.2 — Site moves to free static hosting

- GitHub Pages: `npm run build` → deploy `site/dist` via `actions/deploy-pages` (free forever), or Netlify Drop (even simpler).
- Update README + site links to the permanent URL.

### Task 5.3 — Keep the story alive

- `monitoring/` dashboards still work if pointed at any cluster (document "how to redeploy: 15 minutes from this repo").
- README gets a section: "Cost: $35 over 5 weeks — proof IaC makes platforms disposable."

**Phase 5 done when:** Azure resources destroyed, site on free hosting, repo self-documents everything, demo video posted.

---

## Definition of Done (whole project)

- [ ] Site live on AKS via GitOps with zero manual deploys
- [ ] All 7 domains demonstrable from the repo
- [ ] No static secrets anywhere (OIDC only)
- [ ] Trivy/tfsec clean in CI
- [ ] Monitoring dashboards + uptime probes working
- [ ] README + docs + video + screenshots complete
- [ ] Repo public with strong description
- [ ] Azure destroyed within credit window, site migrated to free hosting

## Risks & Open Questions

| Risk | Mitigation |
|---|---|
| Cluster cost overruns | Destroy between sessions; budget cap tracked weekly |
| Credit expiry mid-build | Calendar reminder 3 days before; teardown script ready |
| AKS deploy latency (10–15 min) | Terraform plan/apply in CI with `-auto-approve` on main only |
| Image pull auth on AKS | Make GHCR package public (fine for portfolio) |
| TLS/HTTPS without a domain | **Resolved (user):** free only — Cloudflare Tunnel (free HTTPS URL) primary, sslip.io HTTP fallback; no domain purchase |
| ArgoCD vs Flux | ArgoCD chosen (most-recognized); AKS GitOps extension (Flux) noted as alternative in README |
| Content: what projects to feature | 1–2 past projects + this pipeline as the flagship; blog posts double as writing samples |
| AGENTS.md mentions Svelte tooling available | Not used — Astro chosen deliberately (static-first, islands); revisit only if user prefers SvelteKit |

## Quick Reference — Key Commands

```bash
# Dev loop
cd site && npm run dev                # local dev
docker build -t golden-path:dev . && docker run -p 8080:80 golden-path:dev

# Infra
cd infra && terraform init && terraform plan && terraform apply
az aks get-credentials -g golden-path-rg -n golden-path-aks
kubectl get pods -n portfolio

# GitOps
kubectl -n argocd port-forward svc/argocd-server 8080:443
argocd app get golden-path

# Monitoring
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# Teardown (end of every session)
cd infra && terraform destroy -auto-approve
```
