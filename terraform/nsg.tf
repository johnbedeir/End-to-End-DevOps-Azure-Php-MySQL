# Create Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name_prefix}-${var.environment}-nsg"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_security_rule" "allow_http_inbound" {
  name                        = "AllowHTTPInbound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "9090", "9093"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.aks.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_sql_server_traffic" {
  name                        = "AllowSQLServerTraffic"
  priority                    = 100   
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["1433"]
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.2.0/24"
  resource_group_name = azurerm_resource_group.aks.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_sql_outbound" {
  name                        = "allow_sql_outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "*"  # Your AKS subnet CIDR block
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = azurerm_resource_group.aks.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate NSG with the subnet where the private endpoint is deployed
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
