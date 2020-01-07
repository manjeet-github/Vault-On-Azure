# - define some local variables
locals {
  virtual_machine_name_AD = "${var.vm_name}-AD"
  virtual_machine_fqdn = "${local.virtual_machine_name_AD}.${var.active_directory_domain}"
  custom_data_params   = "Param($RemoteHostName = \"${local.virtual_machine_fqdn}\", $ComputerName = \"${local.virtual_machine_name_AD}\")"
  custom_data_content  = "${local.custom_data_params} ${file("./files/winrm.ps1")}"

  // The below locals to build the command to install all the windows packages for AD
  // the `exit_code_hack` is to keep the VM Extension resource happy
  import_command       = "Import-Module ADDSDeployment"
  password_command     = "$password = ConvertTo-SecureString ${var.storeWindows_Password} -AsPlainText -Force"
  install_ad_command   = "Add-WindowsFeature -name ad-domain-services -IncludeManagementTools"
  configure_ad_command = "Install-ADDSForest -CreateDnsDelegation:$false -DomainMode Win2012R2 -DomainName ${var.active_directory_domain} -DomainNetbiosName ${var.active_directory_netbios_name} -ForestMode Win2012R2 -InstallDns:$true -SafeModeAdministratorPassword $password -Force:$true"
  shutdown_command     = "shutdown -r -t 10"
  exit_code_hack       = "exit 0"
  powershell_command   = "${local.import_command}; ${local.password_command}; ${local.install_ad_command}; ${local.configure_ad_command}; ${local.shutdown_command}; ${local.exit_code_hack}"

}

# - create a public ip to be attached to the VM NIC
resource "azurerm_public_ip" "windows-public-ip" {
  name                = "${var.prefix}-public-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  allocation_method   = "Dynamic"
  domain_name_label   = "${lower(var.prefix)}-active-directory"

  tags = var.tags
}

# - Create a network interface, assign it to a security group, static private IP
# - attach the public IP from the last resource block
# - Active Directory server needs a static IP .. So the nw interface is hardcoded with static IP
resource "azurerm_network_interface" "windows-vm-nic" {
  name                = "${var.prefix}-windows-vm-nic"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
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

# - Create a certificate in KeyVault, Attach it to the Windows Server
resource "azurerm_key_vault_certificate" "vm_certificate" {
  name         = "${local.virtual_machine_name_AD}-cert"
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

      subject            = "CN=${local.virtual_machine_name_AD}"
      validity_in_months = 12
    }
  }
}


# - Create a new virtual machine with the following configuration
# - Install and run the powershell script
resource "azurerm_virtual_machine" "windows-vm" {
  name                  = local.virtual_machine_name_AD
  resource_group_name   = azurerm_resource_group.example.name
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
    computer_name  = local.virtual_machine_name_AD
    admin_username = var.storeWindows_UserName
    admin_password = var.storeWindows_Password
    custom_data    = local.custom_data_content
  }

  os_profile_secrets {
    source_vault_id = azurerm_key_vault.example.id

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


  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = azurerm_public_ip.windows-public-ip.fqdn
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

}

// NOTE: we **highly recommend** not using this configuration for your Production Environment
// this provisions a single node configuration with no redundancy.
resource "azurerm_virtual_machine_extension" "create-active-directory-forest" {
  name                 = "create-active-directory-forest"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  virtual_machine_name = azurerm_virtual_machine.windows-vm.name
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe -Command \"${local.powershell_command}\""
    }
SETTINGS
}
