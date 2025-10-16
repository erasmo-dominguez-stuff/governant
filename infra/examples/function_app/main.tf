terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

provider "azurerm" { features {} }

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "app_path" { type = string }
variable "tags" { type = map(string) default = {} }

# Package the app folder into a ZIP
# Note: it's recommended to ignore venv/ and temporary artifacts
data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = var.app_path
  output_path = "${path.module}/app.zip"
}

module "function" {
  source              = "../../modules/azure_function"
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  zip_package_path    = data.archive_file.app_zip.output_path
  tags                = var.tags
}

output "function_app_name" {
  value = module.function.function_app_name
}

output "default_hostname" {
  value = module.function.default_hostname
}
