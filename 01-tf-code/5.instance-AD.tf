# - define some local variables
locals {
  virtual_machine_name = "${var.vm_name}-AD"
  virtual_machine_fqdn = "${local.virtual_machine_name}.${var.active_directory_domain}"
  custom_data_params   = "Param($RemoteHostName = \"${local.virtual_machine_fqdn}\", $ComputerName = \"${local.virtual_machine_name}\")"
  custom_data_content  = "${local.custom_data_params} ${file("./files/winrm.ps1")}"

}

# - create a public ip to be attached to the VM NIC
resource "azurerm_public_ip" "windows-public-ip" {
  name                = "${var.prefix}-public-ip"
  resource_group_name = var.name
  location            = var.location
  allocation_method   = "Dynamic"
  domain_name_label   = "${lower(var.prefix)}-active-directory"

  tags = var.tags
}

# - Create a network interface, assign it to a security group, static private IP
# - attach the public IP from the last resource block
resource "azurerm_network_interface" "windows-vm-nic" {
  name                      = "${var.prefix}-windows-vm-nic"
  resource_group_name       = var.name
  location                  = var.location
  network_security_group_id = azurerm_network_security_group.windows-vm-sg.id

  ip_configuration {
    name                          = "${var.prefix}ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.12.4"
    public_ip_address_id          = azurerm_public_ip.windows-public-ip.id
  }

  tags = var.tags
}

# - Create a new virtual machine with the following configuration
# - Install and run the powershell script
resource "azurerm_virtual_machine" "windows-vm" {
  name                  = local.virtual_machine_name
  resource_group_name   = var.name
  location              = var.location
  network_interface_ids = ["${azurerm_network_interface.windows-vm-nic.id}"]
  vm_size               = var.vmsize["medium"]
  tags                  = var.tags

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true


  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.name}vm-osdisk-1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.virtual_machine_name
    admin_username = data.azurerm_key_vault_secret.myWinUser.value
    admin_password = data.azurerm_key_vault_secret.myWinPass.value
    custom_data    = local.custom_data_content
  }

  os_profile_secrets {
    source_vault_id = data.azurerm_key_vault.keyvault.id

    vault_certificates {
      certificate_url   = azurerm_key_vault_certificate.vm_certificate.secret_id
      certificate_store = "My"
    }
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    winrm {
      protocol        = "https"
      certificate_url = azurerm_key_vault_certificate.vm_certificate.secret_id
    }

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${data.azurerm_key_vault_secret.myWinPass.value}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${data.azurerm_key_vault_secret.myWinUser.value}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "${file("./files/FirstLogonCommands.xml")}"
    }
  }


  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = azurerm_public_ip.windows-public-ip.fqdn
      user     = data.azurerm_key_vault_secret.myWinUser.value
      password = data.azurerm_key_vault_secret.myWinPass.value
      port     = 5986
      https    = true
      timeout  = "2m"

      # NOTE: if you're using a real certificate, rather than a self-signed one, you'll want this set to `false`/to remove this.
      insecure = true
    }

    inline = [
      "cd C:\\Windows",
      "dir",
      //"powershell.exe -ExecutionPolicy Unrestricted -Command {Install-WindowsFeature -name Web-Server -IncludeManagementTools}",
    ]
  }

}
