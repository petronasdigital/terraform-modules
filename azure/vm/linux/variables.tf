variable "vnet_rg_name" {}
variable "vnet_name" {}
variable "subnet_name" {}
variable "rg_name" {}
variable "vm_name" {
  default = "VCENPICTDDKUBEP"
}
variable "location" {}
variable "tags" {
  type  = map
}
variable "vm_size" {
  default = "Standard_D2s_v3"
}
variable "ssh_file_content" {}
variable "admin_username" {}
variable "vm_datadisk_size_gb" {
  default = 0
}
variable "vm_image" {
  type  = map
}
variable "vm_ids" {
  type    = list
  default = []
}
variable "create_data_disk" {
  default = true
}
variable "attach_nsg" {
  default = false
}
variable "datadisk_tier" {
  default = "Standard_LRS"
}
variable "private_ip_address" {}
