output "resource_group_name" {
  description = "Main resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Azure region of the main resource group"
  value       = azurerm_resource_group.main.location
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "oidc_issuer_url" {
  description = "AKS OIDC issuer URL (workload identity federations)"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.main.id
}

output "kubeconfig" {
  description = "Raw kubeconfig for the cluster (admin) — stored in state; treat as a secret"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}
