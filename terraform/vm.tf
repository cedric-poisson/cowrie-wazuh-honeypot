resource "azurerm_linux_virtual_machine" "vm_cowrie" {
  name                = "vm-cowrie"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s_v2"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_cowrie.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/homelab_vm_rsa.pub")
    
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }
}


resource "azurerm_linux_virtual_machine" "vm_wazuh" {
  name                = "vm-wazuh"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s_v2"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_wazuh.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/homelab_vm_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }
}