provider "azurerm" {
}

// Create the resource groups
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags     = var.tags
}


## Outputs
output "computer_name_Windows" {
  value = azurerm_virtual_machine.windows-vm.name
}

output "private-ip" {
  value       = azurerm_network_interface.windows-vm-nic.private_ip_address
  description = "Private IP Address"
}

output "public-ip" {
  value       = azurerm_public_ip.windows-public-ip.ip_address
  description = "Public IP Address"
}
