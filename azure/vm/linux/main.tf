data "azurerm_virtual_network" "vnet_name" {
  name                = var.vnet_name
  resource_group_name = var.vnet_rg_name
} 

data "azurerm_subnet" "vm_subnet" {
  name                  = var.subnet_name
  virtual_network_name  = var.vnet_name
  resource_group_name   = var.vnet_rg_name
}
data "azurerm_resource_group" "main" {
  name     = var.rg_name
}

resource "azurerm_network_interface" "main" {
  name                      = var.vm_name
  location                  = data.azurerm_resource_group.main.location
  resource_group_name       = data.azurerm_resource_group.main.name
  enable_ip_forwarding      = true
  tags                      = var.tags

  ip_configuration {
    name                          = format("ipconfig-%s", var.vm_name)
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = try(var.private_ip_address, null)
  }
}

resource "azurerm_virtual_machine" "main" {
  name                          = var.vm_name
  location                      = data.azurerm_resource_group.main.location
  resource_group_name           = data.azurerm_resource_group.main.name
  network_interface_ids         = [azurerm_network_interface.main.id]
  vm_size                       = var.vm_size
  delete_os_disk_on_termination = true
  tags                          = var.tags

  storage_image_reference {
    publisher = try(var.vm_image["publisher"], null)
    offer     = try(var.vm_image["offer"], null)
    sku       = try(var.vm_image["sku"], null)
    version   = try(var.vm_image["version"], null)
    id        = try(var.vm_image["image_id"], null)
  }

  os_profile {
    computer_name   = var.vm_name
    admin_username  = var.admin_username
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data  = var.ssh_file_content
      path      = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }

  storage_os_disk {
    name          = format("disk-%s-OS", var.vm_name)
    create_option = "FromImage"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = var.vm_ids
  }
}

resource "azurerm_managed_disk" "data_disk" {
  name                  = format("disk-%s-data", var.vm_name)
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  storage_account_type  = var.datadisk_tier
  create_option         = "Empty"
  disk_size_gb          = var.vm_datadisk_size_gb
  tags                  = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach-datadisk" {
  managed_disk_id     = azurerm_managed_disk.data_disk.id
  virtual_machine_id  = azurerm_virtual_machine.main.id
  lun                 = 1
  caching             = "ReadWrite"
}
