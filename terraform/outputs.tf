output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "The name of the AKS cluster"
}

output "acr_name" {
  value       = azurerm_container_registry.acr.name
  description = "The acr name"
}

output "aks_cluster_location" {
  value       = azurerm_kubernetes_cluster.aks.location
  description = "The location of the AKS cluster"
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "client_id" {
  value = data.azuread_service_principal.aks.object_id
}

output "client_secret" {
  value = var.client_secret
}

output "principal_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "tenant_id" {
  value = var.tenant_id
}

# Output for the SQL Server endpoint (DB_HOST)
output "db_host" {
  description = "The SQL Server host endpoint"
  value       = azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address
}

# Output for the DB Username (DB_USER)
output "db_username" {
  description = "The SQL Server administrator login username"
  value       = var.db_username
}

# Output for the DB Password (DB_PASSWORD)
output "db_password" {
  description = "The SQL Server administrator login password"
  value       = azurerm_key_vault_secret.db_password.value
  sensitive   = true
}