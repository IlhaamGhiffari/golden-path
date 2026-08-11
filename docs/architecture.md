# Architecture — the golden path in detail

This document walks the pipeline end-to-end, then catalogs the **war stories** —
real problems hit during the build and how they were solved. Every entry here is
something I can defend in an interview because it cost me actual debugging time.

## The pipeline, end to end

```
git push (site/**)
   │
   ▼
GitHub Actions: ci.yml
   ├─ build   npm ci → npm run check (astro check) → npm run build → upload dist
   ├─ scan    docker build → trivy image --severity HIGH,CRITICAL (exit-code 1)
   │          └─ gates the push: dirty images never reach GHCR
   └─ push    docker login GHCR (GITHUB_TOKEN) → build-push-action
              tags: ghcr.io/ilhaamghiffari/golden-path:<sha> + :latest
              └─ bump-image.sh <sha> → sed k8s/deployment.yaml → commit [skip ci] → push
                    │
                    ▼
              ArgoCD Application "golden-path" (automated: prune + selfHeal)
              detects drift on git@github.com:.../k8s → syncs AKS
                    │
                    ▼
              Deployment rollout (2 replicas) → nginx pods serve the new build
                    │
                    ▼
              nginx-ingress controller (TLS via cert-manager/Let's Encrypt)
                    │
                    ▼
              https://ilhaamghiffari.tech (+ www)
```

### Components

| Component | Detail |
|---|---|
| **AKS** | `golden-path-aks`, Kubernetes 1.36.2, 1× `Standard_B2s` system pool, kubenet + **Calico** (Calico = NetworkPolicy support later, without cluster recreation) |
| **Networking** | VNet `10.0.0.0/16`; AKS subnet `10.0.1.0/24`; service CIDR `10.1.0.0/16`, DNS `10.1.0.10` (see war story #2) |
| **Ingress** | ingress-nginx via Helm; hosts `ilhaamghiffari.tech` + `www.ilhaamghiffari.tech`; **TLS** via cert-manager (ClusterIssuer `letsencrypt-prod`, HTTP-01) → Let's Encrypt SAN cert in `golden-path-tls` secret |
| **ArgoCD** | Application source `git@github.com:IlhaamGhiffari/golden-path.git`, path `k8s`, dest `portfolio` ns |
| **Registry** | GHCR package `golden-path` — public (AKS pulls anonymously; no imagePullSecrets) |
| **Key Vault** | `golden-path-kv` (Standard) — exists for the story; workload identity integration is future work |
| **Remote state** | `gpstateilhaam` storage account → `tfstate/golden-path.tfstate` (blob, locked) |

## War stories

### 1. Azure for Students restricts deployable regions

**Symptom:** `az storage account create` failed with `SubscriptionNotFound` (subscription clearly existed), then with
`RequestDisallowedByAzure: This policy maintains a set of best available regions...`.

**Root cause:** the subscription carries a policy assignment (`sys.regionrestriction`) allowing only:
`centralindia, eastasia, malaysiawest, southeastasia, koreacentral`. `eastus`/`westus` are rejected
for resource types like storage accounts.

**Fix:** pinned everything to `southeastasia` (`infra/variables.tf` + `scripts/bootstrap-state.sh`).
Also: the `SubscriptionNotFound` symptom was a red herring — the `Microsoft.Storage` resource provider
was simply not registered yet (`az provider register -n Microsoft.Storage`).

### 2. kubenet's default service CIDR overlaps the VNet

**Symptom:** `400 ServiceCidrOverlapExistingSubnetsCidr` — "service CIDR 10.0.0.0/16 conflicted with existing subnet CIDR 10.0.1.0/24".

**Root cause:** kubenet's default service CIDR is `10.0.0.0/16`, which collides with a VNet I defined as `10.0.0.0/16`.

**Fix:** explicit non-overlapping ranges in `infra/main.tf` → `service_cidr = "10.1.0.0/16"`, `dns_service_ip = "10.1.0.10"`.

### 3. AKS load-balancer health probe 404s against ingress-nginx → public URL times out

**Symptom:** the site worked via `kubectl port-forward` but the public URL timed out **from every network**
(verified with multi-country TCP checks via check-host.net — ruling out an ISP block).

**Root cause:** Azure's default LB health probe for the ingress-nginx service is `HTTP GET /` **without a Host header**.
ingress-nginx answers **404** for unknown hosts → the node is marked unhealthy → the Standard LB drops all traffic.

**Fix:** point the probe at ingress-nginx's healthz endpoint, which always answers 200:
`service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz`
(baked into `k8s/ingress-nginx-values.yaml`).

### 4. trivy-action was supply-chain compromised (Mar 2026)

**Disclosure:** all `aquasecurity/trivy-action` tags **except `v0.35.0`** were affected by a 12-hour tag compromise.

**Response:** the workflow pins the action to the commit SHA of `v0.35.0`
(`57a97c7e7821a5776cebc9bb87c984fa69cba8f1`) with a comment explaining why — tags are mutable, SHAs are not.
Every third-party action in the repo is version-pinned.

### 5. GHCR package visibility: REST 404, GraphQL silent, web UI only

**Symptom:** `PATCH /user/packages/container/golden-path` → 404, even with `write:packages`.
The package was listed by `GET /user/packages/container/golden-path/versions` — but the user-scoped
GraphQL `packages` query didn't return it either.

**Root cause:** packages pushed from Actions with `GITHUB_TOKEN` are **repo-linked**; the visibility
mutation endpoints 404 for them. (The `SubscriptionNotFound`-style red herring of the day.)

**Fix:** change visibility via the GitHub web UI (Package settings → Danger Zone). 30 seconds, zero API.

### 6. GHCR image names must be lowercase

**Symptom:** `push: invalid tag "ghcr.io/IlhaamGhiffari/golden-path:...": repository name must be lowercase`.

**Fix:** `echo "IMAGE=ghcr.io/${GITHUB_REPOSITORY,,}" >> "$GITHUB_ENV"` in the workflow (bash lowercase expansion).

### 7. Version skew: OrbStack bundles an old kubectl

`/usr/local/bin/kubectl` (OrbStack's, v1.33.9) shadowed Homebrew's. The cluster runs 1.36.2 — three minors
apart violates the kubectl skew policy. Fixed by `brew install kubernetes-cli` (1.36.3) and preferring
`/opt/homebrew/bin` in PATH.

## Cost notes

- Phase 1 (site + CI + state bootstrap): ~$1 total
- Cluster running: ~$0.5/day (AKS B2s + disk + LB/public IP) — destroyed between sessions
- GHCR, GitHub Actions, Key Vault: $0

## Teardown

```bash
cd infra && terraform destroy -auto-approve   # cluster + disk + LB + public IP
az group delete -n golden-path-state-rg -y    # last: kills the state container too
```
