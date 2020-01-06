provider "azurerm" {
}

// Create the resource groups
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags     = var.tags
}
