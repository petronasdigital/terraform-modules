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

resource "azurerm_network_security_group" "nic_secgroup" {
  count               = var.vm_count
  name                = "${format("nsg-%s%02.0f", var.vm_name, abs(count.index + 1))}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_network_interface" "main" {
  count                     = var.vm_count
  name                      = "${format("nic-%s%02.0f", var.vm_name, abs(count.index + 1))}"
  location                  = data.azurerm_resource_group.main.location
  resource_group_name       = data.azurerm_resource_group.main.name
  enable_ip_forwarding      = true
  tags                      = var.tags

  ip_configuration {
    name                          = "${format("ipconfig-%s%02.0f", var.vm_name, abs(count.index + 1))}"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.nic_secgroup[count.index].id
}

output "nic_ids" {
  value = azurerm_network_interface.main.*.id
}

output "vm_ips" {
  value = azurerm_network_interface.main.*.private_ip_address
}

resource "azurerm_availability_set" "main" {
  name                        = var.vm_name
  location                    = data.azurerm_resource_group.main.location
  resource_group_name         = data.azurerm_resource_group.main.name
  platform_fault_domain_count = 2
  tags                        = var.tags
}

resource "azurerm_virtual_machine" "main" {
  count                         = var.vm_count
  name                          = "${format("%s%02.0f", var.vm_name, abs(count.index + 1))}"
  location                      = data.azurerm_resource_group.main.location
  resource_group_name           = data.azurerm_resource_group.main.name
  network_interface_ids         = [azurerm_network_interface.main.*.id[count.index]]
  vm_size                       = var.vm_size
  delete_os_disk_on_termination = true
  tags                          = var.tags
  availability_set_id           = azurerm_availability_set.main.id

  storage_image_reference {
    publisher = var.vm_image["publisher"]
    offer     = var.vm_image["offer"]
    sku       = var.vm_image["sku"]
    version   = var.vm_image["version"]
  }

  os_profile {
    computer_name   = "${format("%s%02.0f", var.vm_name, abs(count.index + 1))}"
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
    name          = "${format("disk-%s%02.0f-OS", var.vm_name, abs(count.index + 1))}"
    create_option = "FromImage"
  }

  dynamic "identity" {
    for_each = var.vm_ids
    content {
      type          = "UserAssigned"
      identity_ids  = [identity.value]
    }
  }
}

resource "azurerm_managed_disk" "data_disk" {
  count                 = var.create_data_disk ? var.vm_count : 0
  name                  = "${format("disk-%s%02.0f-data", var.vm_name, abs(count.index + 1))}"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = var.vm_datadisk_size_gb
  tags                  = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach-datadisk" {
  count                 = var.create_data_disk ? var.vm_count : 0
  managed_disk_id     = azurerm_managed_disk.data_disk.*.id[count.index]
  virtual_machine_id  = azurerm_virtual_machine.main.*.id[count.index]
  lun                 = "${count.index + 1}"
  caching             = "ReadWrite"
}
