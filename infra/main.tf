# Main resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# --- Networking ---
resource "azurerm_virtual_network" "main" {
  name                = "golden-path-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- AKS ---
resource "azurerm_kubernetes_cluster" "main" {
  name                = "golden-path-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "goldenpath"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    network_policy = "calico" # enables NetworkPolicy resources (Phase 3) without cluster recreation
    # kubenet default service CIDR is 10.0.0.0/16 which overlaps our VNet — set explicit non-overlapping ranges
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  oidc_issuer_enabled               = true # workload identity (Phase 3+)
  azure_policy_enabled              = true # Azure Policy for AKS
  role_based_access_control_enabled = true

  # --- security hardening ---
  api_server_access_profile {
    # API server reachable only from our public IP (residential — if it changes,
    # update via terraform apply; ARM management plane is NOT affected).
    authorized_ip_ranges = ["182.10.225.250/32"]
  }
  # AAD-only auth: disables the unauthenticated local "clusterAdmin" kubeconfig.
  # `az aks get-credentials` (AAD token) keeps working.
  local_account_disabled = true

  tags = {
    project = "golden-path"
  }
}

# --- Key Vault (Standard, ~free tier) ---
resource "azurerm_key_vault" "main" {
  name                       = "golden-path-kv"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  # deny-by-default: no public data-plane access; only Azure services may bypass.
  # (management plane via ARM is unaffected — terraform apply still works)
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

data "azurerm_client_config" "current" {}
