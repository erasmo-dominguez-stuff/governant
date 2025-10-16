output "function_app_id" {
  description = "ID of the Function App"
  value       = azurerm_linux_function_app.this.id
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.this.name
}

output "default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.this.default_hostname
}

output "run_from_package_url" {
  description = "URL (with SAS) used in WEBSITE_RUN_FROM_PACKAGE"
  value       = local.run_from_package_url
}
