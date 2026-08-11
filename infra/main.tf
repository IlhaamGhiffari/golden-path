# Main resource group — Phase 1: bootstrap only. AKS, VNet, Key Vault land in Phase 2.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}
