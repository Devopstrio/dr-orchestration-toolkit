provider "azurerm" {
  features {}
}

provider "aws" {
  region = var.aws_region
}

resource "azurerm_resource_group" "dr" {
  name     = "rg-${var.project_name}-dr-${var.environment}"
  location = var.location
}

# --- Resilience Control Plane (AKS) ---

resource "azurerm_kubernetes_cluster" "dr_k8s" {
  name                = "aks-resilience-iq-${var.environment}"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  dns_prefix          = "resilience-k8s"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }
}

# --- Resilience Metadata Store (Postgres) ---

resource "azurerm_postgresql_flexible_server" "resilience" {
  name                   = "psql-resilience-metadata-${var.environment}"
  resource_group_name    = azurerm_resource_group.dr.name
  location               = azurerm_resource_group.dr.location
  version                = "13"
  administrator_login    = "dradmin"
  administrator_password = var.db_password
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2ds_v4"
}

# --- Multi-Cloud Persistence (AWS S3 Recovery Sink) ---

resource "aws_s3_bucket" "recovery_sink" {
  bucket = "db-resilience-recovery-sink-${var.environment}"
}

# --- Secure Resilience Secrets (Azure Key Vault) ---

resource "azurerm_key_vault" "vault" {
  name                        = "kv-resilience-${var.environment}"
  location                    = azurerm_resource_group.dr.location
  resource_group_name         = azurerm_resource_group.dr.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}
