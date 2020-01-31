provider "azurerm" {
  version = "=1.36.0"
}

// Create the resource groups
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags     = var.tags
}


## Outputs from Windows Active Directory Server
output "Windows-Active-Directory-Hostname" {
  value = azurerm_virtual_machine.windows-ad-vm.name
}

output "Windows-Active-Directory-private-ip" {
  value       = azurerm_network_interface.windows-ad-vm-nic.private_ip_address
  description = "Private IP Address"
}

output "Windows-Active-Directory-public-ip" {
  value       = azurerm_public_ip.windows-ad-public-ip.ip_address
  description = "Public IP Address"
}
