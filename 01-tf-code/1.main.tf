provider "azurerm" {
}

// Create the resource groups
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags     = var.tags
}

# - Fetch the Key Vault resource details
data "azurerm_key_vault" "keyvault" {
  name                = "${var.prefix}-keyvault"
  resource_group_name = azurerm_resource_group.example.name
}

# - Fetch the default admin username for windows vm
data "azurerm_key_vault_secret" "myWinUser" {
  name         = var.vault_id_for_username
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

# - Fetch the default admin password for windows vm
data "azurerm_key_vault_secret" "myWinPass" {
  name         = var.vault_id_for_password
  key_vault_id = data.azurerm_key_vault.keyvault.id
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
