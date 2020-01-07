resource "azurerm_virtual_machine_scale_set" "example-vault-cluster" {
  name = "${var.prefix}-vault-cluster"
  location = var.location
  resource_group_name = azurerm_resource_group.example.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_F2"
    tier     = "Standard"
    capacity = 3
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "myadmin"
    admin_password       = "Hashicorppnc@#$"
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
    id = "/subscriptions/14692f20-9428-451b-8298-102ed4e39c2a/resourceGroups/pncvaultpoc2019img/providers/Microsoft.Compute/images/RHEL-7_Vault-2019-12-18-143051"
  }
  
  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
}