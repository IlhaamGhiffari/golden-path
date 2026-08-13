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
  description = "Your public IP (no /32 suffix). AKS API server is locked down to this IP (security.md). Residential IPs are dynamic — when it changes, `terraform apply` with the new value (or `az aks update --api-server-authorized-ip-ranges <ip>/32` for an immediate fix)."
  type        = string
  default     = "182.10.225.141"
}
