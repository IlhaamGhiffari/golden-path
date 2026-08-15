variable "location" {
  description = "Azure region for resources. Azure for Students restricts regions to: centralindia, eastasia, malaysiawest, southeastasia, koreacentral"
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Main resource group name"
  type        = string
  default     = "golden-path-rg"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (pin for reproducibility)"
  type        = string
  default     = "1.36.2"
}

variable "home_ip" {
  description = "Your public IPv4 (no /32 suffix). AKS API server is locked down to this IP (security.md). No default (audit fix: a residential IP in git aids targeted recon) — supply via TF_VAR_home_ip, a terraform.tfvars (gitignored, see terraform.tfvars.example), or -var. Residential IPs are dynamic: when it changes, update terraform.tfvars + apply, or `az aks update --api-server-authorized-ip-ranges <ip>/32` for an immediate fix."
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", var.home_ip))
    error_message = "home_ip must be a bare IPv4 address without a /32 suffix (e.g. 203.0.113.7)."
  }
}
