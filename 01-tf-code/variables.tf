##############################################################################
# Variables File
# 
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)

variable "prefix" {
  description = "This prefix will be included in the name of most resources."
}

variable "name" {
  description = "This prefix will be included in the name of most resources."
  default     = "se-hangout-01102020"
}

variable "location" {
  description = "The region where the virtual network is created."
  default     = "East US"
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = map(string)
  default     = {}
}

// - Note the below variables can be pulled from HashiCorp Vault.
variable "storeWindows_UserName" {
  description = "Define the admin UserName to be used for provisioning the VM's"
}

variable "storeWindows_Password" {
  description = "Define the admin Password to be used for provisioning the VM's"
}


// - variable definitions for network resources.
variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.10.0/24"
}

