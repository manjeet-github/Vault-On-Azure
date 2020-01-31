prefix                        = "singhdemo-rg"
name                          = "singhdemo-ad"
location                      = "West US"
storeWindows_UserName         = "testadmin"
storeWindows_Password         = "HashiDemoPass1234"
active_directory_domain       = "hashidemos.com"
active_directory_netbios_name = "hashidemos" # 15 char limit

vm_name                    = "win-vm"
vault_instance_username    = "myadmin"
vault_instance_password    = "HashiDemoPass1234"
vault_instance_count       = 1
vault_instance_name_prefix = "vault-vm"
vault_instance_reference   = "/subscriptions/14692f20-9428-451b-8298-102ed4e39c2a/resourceGroups/pncvaultpoc2019img/providers/Microsoft.Compute/images/sehangout-vault-rhel-2020-01-07-220142"


tags = {
  "Owner"       = "manjeet@hashicorp.com",
  "TTL"         = "24",
  "Customer"    = "HashiCorp",
  "Environment" = "developer workstations"
}

address_space         = "10.0.0.0/16"
subnet_prefix         = "10.0.4.0/24"
dns_servers           = "10.0.4.4"
vault_id_for_password = "dummypassword"
vault_id_for_username = "dummyuser"
