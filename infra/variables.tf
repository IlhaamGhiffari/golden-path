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
