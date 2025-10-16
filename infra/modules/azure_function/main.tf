terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Storage account for Function state and package hosting
resource "random_string" "sa" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  sa_name        = lower(replace(substr("${var.name}${random_string.sa.result}", 0, 24), "-", ""))
  container_name = "packages"
  blob_name      = "${var.name}.zip"
}

resource "azurerm_storage_account" "this" {
  name                     = local.sa_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = true
  tags = var.tags
}

resource "azurerm_storage_container" "pkg" {
  name                  = local.container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "pkg" {
  name                   = local.blob_name
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.pkg.name
  type                   = "Block"
  source                 = var.zip_package_path
  content_type           = "application/zip"
}

data "azurerm_storage_account_sas" "pkg" {
  connection_string = azurerm_storage_account.this.primary_connection_string

  https_only = true
  start      = timestamp()
  expiry     = timeadd(timestamp(), "168h") # 7 days

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = true
    add     = false
    create  = false
    update  = false
    process = false
  }
}

locals {
  run_from_package_url = "https://${azurerm_storage_account.this.name}.blob.core.windows.net/${azurerm_storage_container.pkg.name}/${azurerm_storage_blob.pkg.name}${data.azurerm_storage_account_sas.pkg.sas}"
}

# Consumption plan for Functions (Linux)
resource "azurerm_service_plan" "this" {
  name                = "${var.name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "this" {
  name                       = var.name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.this.id
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key

  site_config {
    application_stack {
      python_version = var.python_version
    }
    use_32_bit_worker = false
    ftps_state        = "Disabled"
  }

  app_settings = merge({
    FUNCTIONS_WORKER_RUNTIME   = "python"
    FUNCTIONS_EXTENSION_VERSION = "~4"
    WEBSITE_RUN_FROM_PACKAGE   = local.run_from_package_url
    AzureWebJobsStorage        = azurerm_storage_account.this.primary_connection_string
  }, var.app_settings)

  tags = var.tags
}
