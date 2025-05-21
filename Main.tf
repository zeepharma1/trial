terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "terra_rg" {
  name     = "terra-rg"
  location = "East US"
}

# 2. Virtual Network
resource "azurerm_virtual_network" "terra_vnet" {
  name                = "terra-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name
}

# 3. Subnet
resource "azurerm_subnet" "terra_subnet" {
  name                 = "terra-subnet"
  resource_group_name  = azurerm_resource_group.terra_rg.name
  virtual_network_name = azurerm_virtual_network.terra_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Network Security Group
resource "azurerm_network_security_group" "terra_nsg" {
  name                = "terra-nsg"
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. Network Interface & Public IPs
resource "azurerm_public_ip" "terra_pip" {
  name                = "terra-pip-${count.index}"
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "terra_nic" {
  name                = "terra-nic-${count.index}"
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.terra_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.terra_pip[count.index].id
  }
}

# 6. Virtual Machines
variable "server_names" {
  type    = list(string)
  default = ["vm2"]
}

resource "azurerm_linux_virtual_machine" "terra_vm" {
  count               = 1
  name                = var.server_names[count.index]
  resource_group_name = azurerm_resource_group.terra_rg.name
  location            = azurerm_resource_group.terra_rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_password      = "Zeecloud@123"  # Make sure this meets Azure's password complexity

  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.terra_nic[count.index].id
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Name = var.server_names[count.index]
  }
}

# 7. Output
output "vm_details" {
  value = [
    for i in azurerm_linux_virtual_machine.terra_vm : {
      name       = i.name
      public_ip  = azurerm_public_ip.terra_pip[i.count.index].ip_address
      private_ip = azurerm_network_interface.terra_nic[i.count.index].private_ip_address
    }
  ]
}
