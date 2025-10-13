variable "name" {
  description = "Base name for the Azure Function App and related resources"
  type        = string
}

variable "location" {
  description = "Azure region (e.g., westeurope)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of an existing Resource Group"
  type        = string
}

variable "zip_package_path" {
  description = "Local path to the ZIP package to deploy (Python app + Wasm)"
  type        = string
}

variable "python_version" {
  description = "Python version for the Function App runtime"
  type        = string
  default     = "3.11"
}

variable "app_settings" {
  description = "Additional application settings for the Function App"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
