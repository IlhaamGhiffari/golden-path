# Security posture

A platform-engineering portfolio should be able to answer "what would you do about X?" — this
document is the honest state of the security controls, split into **in place**, **planned**,
and the **reasoning** behind each choice.

## In place today

| Control | Where | Detail |
|---|---|---|
| Container scanning | CI (`ci.yml` scan job) | Trivy, `--severity HIGH,CRITICAL --exit-code 1` — a dirty image **cannot** reach GHCR |
| Supply-chain hardening | `.github/workflows/ci.yml` | trivy-action pinned to commit SHA `57a97c7e…` (post-compromise); all Actions version-pinned |
| Base-image patching | `site/Dockerfile` | `apk upgrade --no-cache` in the serve stage — closes Alpine CVEs (libxml2, musl, zlib, nghttp2…) at build time. Trivy result: **0 vulnerabilities** |
| Non-root runtime | `site/Dockerfile`, `k8s/deployment.yaml` | `USER nginx` (uid 101); `runAsNonRoot: true`, `runAsUser/Group: 101`, `fsGroup: 101` |
| Read-only root FS | `k8s/deployment.yaml` | `readOnlyRootFilesystem: true`; writable paths (`/var/cache/nginx`, `/var/run`, `/var/log/nginx`) are explicit `emptyDir` mounts |
| Capability drops | `k8s/deployment.yaml` | `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault` — the deployment is **PSA `restricted`-compliant by design** (label enforcement is Phase 3) |
| Edge hardening | `site/nginx.conf` | CSP, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `server_tokens off` (no version banner) |
| Secrets hygiene | repo-wide | Terraform state lives only in Azure Storage; no `.env`/credentials committed; ArgoCD auth = **scoped read-only SSH deploy key** (revocable, repo-level, not an account PAT) |
| Pull-path auth | GHCR | package is public → AKS pulls anonymously; **no imagePullSecret / static registry credential** in the cluster |
| Healthcheck | `site/Dockerfile` | `HEALTHCHECK` via wget — orchestrators get a liveness signal from the container itself |

## Planned (Phase 3)

| Control | Why it matters |
|---|---|
| **OIDC federation for Azure in CI** | Replace long-lived service principal secrets with short-lived federated tokens — the flagship "no static secrets" story. (Today CI only authenticates to GHCR via `GITHUB_TOKEN`, which is itself short-lived — but Azure auth is still on the interactive CLI path.) |
| **PSA `restricted` label on `portfolio` ns** | Admission control proof — the deployment is already compliant, so enabling it is a `kubectl label` away |
| **Default-deny NetworkPolicy** | Calico is already the network policy provider on the cluster; the manifest ships in Phase 3 (allow ingress-nginx → app, app → DNS/egress only) |
| **IaC scanning** | tfsec/Checkov job on `infra/` in CI |
| **HSTS** | Deferred to when TLS lands (Cloudflare Tunnel) — a no-op header over plain HTTP is theater |
| **Azure Policy for AKS** | Already enabled in Terraform (`azure_policy_enabled = true`) |

## Threat-model thinking (short version)

1. **Someone gets write access to this repo** → CI runs their code. Mitigations: Actions pinned, scans gate the push, secrets are short-lived tokens, and the whole platform is disposable (`terraform destroy` restores the world in ~15 min).
2. **The cluster is compromised** → pods run as non-root with read-only FS and no caps; default-deny netpol (planned) would contain east-west movement; Key Vault holds nothing critical yet; nothing in the cluster can mint Azure credentials (workload identity is deliberately not wired up).
3. **The public edge is scanned/probed** → nginx answers 404/403, no version banner, no TLS yet (planned), CSP prevents injection-styled payloads from running in-browser.

## Known gaps (honest)

- No TLS yet (plain HTTP via sslip.io) — Cloudflare Tunnel is the planned fix (free HTTPS, no domain)
- Admin credentials for ArgoCD/Key Vault follow the vendor defaults on a fresh install — acceptable because the cluster is ephemeral and ArgoCD is only reachable via `kubectl port-forward`, but it's on the list
- No runtime vulnerability scanning of running images (trivy scans at build time; Falco-style runtime monitoring is future work)
