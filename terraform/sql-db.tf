# Azure SQL Server
resource "azurerm_mssql_server" "sql_server" {
  name                         = "${var.name_prefix}-${var.environment}-sql-server"
  resource_group_name          = azurerm_resource_group.aks.name
  location                     = azurerm_resource_group.aks.location
  version                      = "12.0"
  administrator_login          = var.db_username
  administrator_login_password = azurerm_key_vault_secret.db_password.value

  # Ensure SQL server creation depends on Key Vault and secrets
  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_key_vault_secret.db_username,
    azurerm_key_vault_secret.db_password
  ]

  tags = {
    environment = var.environment
  }
}

# Azure SQL Database
resource "azurerm_mssql_database" "sql_database" {
  name      = var.database_name
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "GP_Gen5_2"

  depends_on = [
    azurerm_mssql_server.sql_server
  ]

  tags = {
    environment = var.environment
  }
}


# Private Link for SQL Server (optional, for private access)
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "${var.name_prefix}-${var.environment}-sql-pe"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  subnet_id           = azurerm_subnet.private_subnet.id

  private_service_connection {
    name                           = "sqlserver-private-link"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  depends_on = [
    azurerm_mssql_server.sql_server
  ]

  tags = {
    environment = var.environment
  }
}

resource "azurerm_private_dns_zone" "sql_private_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "${var.name_prefix}-${var.environment}-dns-link"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_private_dns.name
  virtual_network_id    = azurerm_virtual_network.vpc_network.id
}

resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sql_server.name
  resource_group_name = azurerm_resource_group.aks.name
  zone_name           = azurerm_private_dns_zone.sql_private_dns.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address]
}

resource "azurerm_sql_firewall_rule" "allow_connection" {
  name                = "AllowMyIP"
  resource_group_name = azurerm_resource_group.aks.name
  server_name         = azurerm_mssql_server.sql_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}
