terraform {
  required_version = ">= 0.15.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

//Criação do Resource Group
resource "azurerm_resource_group" "as02-infra-terraform" {
    name     = "as02-infra-terraform"
    location = "eastus"
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on = [azurerm_linux_virtual_machine.as02-vm]
  create_duration = "30s"
}

resource "null_resource" "upload_db" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = "azureuser"
            password = "adminuser@2021"
            host = azurerm_public_ip.as02-publicip.ip_address
        }
        source = "mysql"
        destination = "/home/azureuser"
    }
    depends_on = [time_sleep.wait_30_seconds_db]
}

resource "null_resource" "install-mysql" {
    triggers = {
        order = null_resource.upload_db.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = "azureuser"
            password = "adminuser@2021"
            host = azurerm_public_ip.as02-publicip.ip_address
        }
        
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo mysql < /home/azureuser/mysql/config/impacta-infra-db.sql",
            "sudo cp -f /home/azureuser/mysql/config/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20",
        ]
    }
}

//Criação da  Rede Virtualizada
resource "azurerm_virtual_network" "as02-network" {
    name                = "vnet"
    location            = azurerm_resource_group.as02-infra-terraform.location
    resource_group_name = azurerm_resource_group.as02-infra-terraform.name
    address_space       = ["10.0.0.0/16"]
}

//Criação da Subrede Virtualizada
resource "azurerm_subnet" "as02-subnet" {
    name                 = "vsubnet"
    resource_group_name  = azurerm_resource_group.as02-infra-terraform.name
    virtual_network_name = azurerm_virtual_network.as02-network.name
    address_prefixes       = ["10.0.1.0/24"]
}

//Criação do Grupo de Segurança
resource "azurerm_network_security_group" "as02-nsg" {
    name                = "networksecuritygroup"
    location            = azurerm_resource_group.as02-infra-terraform.location
    resource_group_name = azurerm_resource_group.as02-infra-terraform.name

    security_rule {
        name                       = "mysql"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3306"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "SSH"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

//Criação do IP Publico
resource "azurerm_public_ip" "as02-publicip" {
    name                         = "ippublic"
    location                     = azurerm_resource_group.as02-infra-terraform.location
    resource_group_name          = azurerm_resource_group.as02-infra-terraform.name
    allocation_method            = "Static"
}

//Criação da Placa de Rede da VM
resource "azurerm_network_interface" "as02-nic" {
    name                      = "networkinterface"
    location                  = azurerm_resource_group.as02-infra-terraform.location
    resource_group_name       = azurerm_resource_group.as02-infra-terraform.name

    ip_configuration {
        name                          = "ipvm"
        subnet_id                     = azurerm_subnet.as02-subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.as02-publicip.id
    }
}

//Grupo de Associação
resource "azurerm_network_interface_security_group_association" "as02-nsg" {
    network_interface_id      = azurerm_network_interface.as02-nic.id
    network_security_group_id = azurerm_network_security_group.as02-nsg.id
}

resource "azurerm_linux_virtual_machine" "as02-vm" {
    name                  = "virtualmachine"
    location              = azurerm_resource_group.as02-infra-terraform.location
    resource_group_name   = azurerm_resource_group.as02-infra-terraform.name
    size                  = "Standard_DS1_v2"
    admin_username        = "azureuser"
    admin_password        = "adminuser@2021"
    disable_password_authentication = false
    
    network_interface_ids = [azurerm_network_interface.as02-nic.id]
    
    os_disk {
        name              = "diskSO"
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
}