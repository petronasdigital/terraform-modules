data "azurerm_virtual_network" "vnet_name" {
  name                = "${var.vnet_name}"
  resource_group_name = "${var.vnet_rg_name}"
} 

data "azurerm_subnet" "vm_subnet" {
  name                  = "${var.subnet_name}"
  virtual_network_name  = "${var.vnet_name}"
  resource_group_name   = "${var.vnet_rg_name}"
}
data "azurerm_resource_group" "main" {
  name     = "${var.rg_name}"
}

resource "azurerm_network_security_group" "nic_secgroup" {
  count               = "${var.vm_count}"
  name                = "${format("nsg-%s%02.0f", var.vm_name, abs(count.index + 1))}"
  location            = "${data.azurerm_resource_group.main.location}"
  resource_group_name = "${data.azurerm_resource_group.main.name}"
  tags                = "${var.tags}"

  security_rule {
    name                        = "AllowVnetInBound"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "VirtualNetwork"
    destination_address_prefix  = "VirtualNetwork"
    access                      = "Allow"
    priority                    = "3000"
    direction                   = "Inbound"
  }

  security_rule {
    name                        = "AllowAzureLoadBalancerInBound"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "AzureLoadBalancer"
    destination_address_prefix  = "*"
    access                      = "Allow"
    priority                    = "3001"
    direction                   = "Inbound"
  }

  security_rule {
    name                        = "DenyAllInBound"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    access                      = "Deny"
    priority                    = "3500"
    direction                   = "Inbound"
  }

  security_rule {
    name                        = "AllowVnetOutBound"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "VirtualNetwork"
    destination_address_prefix  = "VirtualNetwork"
    access                      = "Allow"
    priority                    = "3000"
    direction                   = "Outbound"
  }

  security_rule {
    name                        = "AllowInternetOutBound"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "Internet"
    access                      = "Allow"
    priority                    = "3001"
    direction                   = "Outbound"
  }

  security_rule {
    name                        = "DenyAllOutBound"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    access                      = "Deny"
    priority                    = "3500"
    direction                   = "Outbound"
  }
}

resource "azurerm_network_interface" "main" {
  count                     = "${var.vm_count}"
  name                      = "${format("nic-%s%02.0f", var.vm_name, abs(count.index + 1))}"
  location                  = "${data.azurerm_resource_group.main.location}"
  resource_group_name       = "${data.azurerm_resource_group.main.name}"
  #network_security_group_id = "${azurerm_network_security_group.nic_secgroup.*.id[count.index]}"
  enable_ip_forwarding      = "true"
  tags                      = "${var.tags}"

  ip_configuration {
    name                          = "${format("ipconfig-%s%02.0f", var.vm_name, abs(count.index + 1))}"
    subnet_id                     = "${data.azurerm_subnet.vm_subnet.id}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "main" {
  count                         = "${var.vm_count}"
  name                          = "${format("%s%02.0f", var.vm_name, abs(count.index + 1))}"
  location                      = "${data.azurerm_resource_group.main.location}"
  resource_group_name           = "${data.azurerm_resource_group.main.name}"
  network_interface_ids         = ["${azurerm_network_interface.main.*.id[count.index]}"]
  vm_size                       = "${var.vm_size}"
  delete_os_disk_on_termination = true
  tags                          = "${var.tags}"

  os_profile {
    computer_name   = "${format("%s%02.0f", var.vm_name, abs(count.index + 1))}"
    admin_username  = "${var.admin_username}"
    admin_password  = "${var.admin_password}"
  }

  os_profile_windows_config {
    enable_automatic_upgrades = false
    timezone                  = "Singapore Standard Time"
  }

  storage_os_disk {
    name          = "${format("disk-%s%02.0f-OS", var.vm_name, abs(count.index + 1))}"
    create_option = "FromImage"
  }

  storage_image_reference {
     publisher = "${var.vm_image["publisher"]}"
     offer     = "${var.vm_image["offer"]}"
     sku       = "${var.vm_image["sku"]}"
     version   = "${var.vm_image["version"]}"
     id        = "${var.vm_image["id"]}"
   }
}

resource "azurerm_managed_disk" "data_disk" {
  count                 = "${var.vm_count}"
  name                  = "${format("disk-%s%02.0f-data", var.vm_name, abs(count.index + 1))}"
  resource_group_name   = "${data.azurerm_resource_group.main.name}"
  location              = "${data.azurerm_resource_group.main.location}"
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = "${var.vm_datadisk_size_gb}"
  tags                  = "${var.tags}"
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach-datadisk" {
  count               = "${var.vm_count}"
  managed_disk_id     = "${azurerm_managed_disk.data_disk.*.id[count.index]}"
  virtual_machine_id  = "${azurerm_virtual_machine.main.*.id[count.index]}"
  lun                 = "${count.index + 1}"
  caching             = "ReadWrite"
}
