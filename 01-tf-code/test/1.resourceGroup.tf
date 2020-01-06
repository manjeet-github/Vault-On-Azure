provider "azurerm" {
}

// Create the resource groups
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = "${var.location}"
  tags     = "${var.tags}"
}

## Outputs
output "resourcegroup-id" {
  value       = "${azurerm_resource_group.create-rg.id}"
  description = "Resource Group ID"
}

output "resourcegroup-name" {
  value       = "${azurerm_resource_group.create-rg.name}"
  description = "Resource Group Name"
}
