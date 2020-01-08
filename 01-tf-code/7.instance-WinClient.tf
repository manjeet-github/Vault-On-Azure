locals {
  virtual_machine_name_winclient = "${var.vm_name}-client"
  virtual_machine_fqdn_winclient = "${local.virtual_machine_name_winclient}.${var.active_directory_domain}"
  custom_data_params_winclient   = "Param($RemoteHostName = \"${local.virtual_machine_fqdn_winclient}\", $ComputerName = \"${local.virtual_machine_name_winclient}\")"
  custom_data_content_winclient  = "${local.custom_data_params} ${file("./files/winrm.ps1")}"
}

# -- PROVISION NETWORK RESOURCES
resource "azurerm_public_ip" "windows-client-public-ip" {
  count               = var.winclient_vmcount
  name                = "win-vm-public-ip-${count.index}"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  allocation_method   = "Dynamic"
  domain_name_label   = "${lower(var.prefix)}-client-${count.index}"

  tags = merge(
    map(
      "Name", "win-vm-public-ip-${count.index}",
      "Description", "This is public ip object to be attached to the network card"
    ), var.tags)
}

resource "azurerm_network_interface" "windows-client-vm-nic" {
  count                     = var.winclient_vmcount
  name                      = "win-client-vm-nic-${count.index}"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = var.location
  network_security_group_id = azurerm_network_security_group.windows-vm-sg.id
  dns_servers               = ["10.0.12.4"] #- This is needed for the clients to join the AD domain

  ip_configuration {
    name                          = "nic-ipconfig-${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = element(azurerm_public_ip.windows-client-public-ip.*.id, count.index)
  }

  tags = merge(
    map(
      "Name", "win-client-vm-public-ip-${count.index}",
      "Description", "This is network card interface object"
    ), var.tags)
  
}

# -- PROVISION CERTIFICATE IN AZ KEY-VAULT
# - Create a certificate in KeyVault, Attach it to the Windows Server
resource "azurerm_key_vault_certificate" "client_vm_certificate" {
  count        = var.winclient_vmcount
  name         = "${local.virtual_machine_name_winclient}-${count.index}-cert"
  key_vault_id = azurerm_key_vault.example.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=${local.virtual_machine_name_winclient}-${count.index}"
      validity_in_months = 12
    }
  }
}

resource "azurerm_virtual_machine" "windows-client-vm" {
  count                 = var.winclient_vmcount
  name                  = "${local.virtual_machine_name_winclient}-${count.index}"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = var.location
  network_interface_ids = ["${element(azurerm_network_interface.windows-client-vm-nic.*.id, count.index)}"]
  vm_size               = var.vmsize["medium"]

  tags = merge(
    map(
      "Name", "win-client-virtual-machine-${count.index}",
      "Description", "This is windows vm workstation client for developers"
    ), var.tags)

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true


  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.name}-vm-osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name_winclient}-${count.index}"
    admin_username = var.storeWindows_UserName
    admin_password = var.storeWindows_Password
    custom_data    = local.custom_data_content_winclient
  }

  os_profile_secrets {
    source_vault_id = azurerm_key_vault.example.id

    vault_certificates {
      certificate_url   = element(azurerm_key_vault_certificate.client_vm_certificate.*.secret_id, count.index)
      certificate_store = "My"
    }
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    winrm {
      protocol        = "https"
      certificate_url = element(azurerm_key_vault_certificate.client_vm_certificate.*.secret_id, count.index)
    }

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>var.storeWindows_Password</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>var.storeWindows_UserName</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = file("./files/FirstLogonCommands.xml")
    }
  }
/* -- Disabled remote provisioner --
  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = element(azurerm_public_ip.windows-client-public-ip.*.fqdn, count.index)
      user     = var.storeWindows_UserName
      password = var.storeWindows_Password
      port     = 5986
      https    = true
      timeout  = "4m"

      # NOTE: if you're using a real certificate, rather than a self-signed one, you'll want this set to `false`/to remove this.
      insecure = true
    }

    inline = [
      "cd C:\\Windows",
      "dir",
      //"powershell.exe -ExecutionPolicy Unrestricted -Command {Install-WindowsFeature -name Web-Server -IncludeManagementTools}",
    ]
  }
  */

}

# -- Code to join the windows clients to the AD Domain
resource "azurerm_virtual_machine_extension" "join-domain" {
  count                = var.winclient_vmcount
  name                 = element(azurerm_virtual_machine.windows-client-vm.*.name, count.index)
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  virtual_machine_name = element(azurerm_virtual_machine.windows-client-vm.*.name, count.index)
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  depends_on  = [azurerm_virtual_machine_extension.create-active-directory-forest]

  # NOTE: the `OUPath` field is intentionally blank, to put it in the Computers OU
  settings = <<SETTINGS
    {
        "Name": "${var.active_directory_domain}",
        "OUPath": "",
        "User": "${var.active_directory_domain}\\${var.storeWindows_UserName}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<SETTINGS
    {
        "Password": "${var.storeWindows_Password}"
    }
SETTINGS

}