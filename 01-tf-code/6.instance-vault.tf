#set up VMs based on a packer image with built in vault
# we are using scaled set as vault clusters typically have more than one identical servers.
resource "azurerm_virtual_machine_scale_set" "example-vault-cluster" {
  name = "${var.prefix}-vault-cluster"
  location = var.location
  resource_group_name = azurerm_resource_group.example.name
  upgrade_policy_mode = "Manual"

  sku {
    #this can be changed if a faster / better performant machine is required.
    name     = "Standard_F2"  
    tier     = "Standard"
    capacity = var.vault_instance_count
  }

  os_profile {
    computer_name_prefix = var.vault_instance_name_prefix
    admin_username       = var.vault_instance_username
    admin_password       = var.vault_instance_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    #ssh_keys {
    #  path = "/home/myadmin/.ssh/authorized_keys"
    #  key_data = file("${path.module}/ssh_authorized_keys.txt")
    #}
  }


  network_profile {
    name = "${var.prefix}-vault-network-profile"
    primary = true

    ip_configuration {
      name = "${var.prefix}-vault-ip-configuration"
      primary = true
      subnet_id = azurerm_subnet.subnet.id
      #load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.vault_bepool.id}"]
      #load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_pool.vault_lbnatpool.id}"]

       public_ip_address_configuration {
          name = "${var.prefix}-vault-ip-public"
          idle_timeout = 5
          domain_name_label = "${var.prefix}vaultdemo"
       }
    }

    network_security_group_id = azurerm_network_security_group.vault-vm-sg.id

   
  }

  storage_profile_image_reference {
    id = var.vault_instance_reference
  }
  
  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
}