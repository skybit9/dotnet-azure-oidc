terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateacct2db2b4c2"
    container_name       = "tfstate"
    key                  = "dotnet-app.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------
variable "resource_group_name" {
  description = "Azure Resource Group name"
  default     = "dotnet-app-rg"
}

variable "location" {
  description = "Azure region"
  default     = "canadacentral"
}

variable "app_service_plan_name" {
  description = "App Service Plan name"
  default     = "dotnet-app-asp"
}

variable "webapp_name" {
  description = "Web App name (must be globally unique)"
  default     = "my-dotnet-app-dev"
}

variable "dotnet_version" {
  description = ".NET version for Linux web app"
  default     = "10.0"
}

variable "github_org" {
  description = "GitHub org or username"
}

variable "github_repo" {
  description = "GitHub repository name"
}

variable "github_environment" {
  description = "GitHub Actions environment name (must match deploy workflow)"
  default     = "dev"
}

# -----------------------------------------------------------------------
# Data: Current Subscription
# -----------------------------------------------------------------------
data "azurerm_subscription" "current" {}

# -----------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# -----------------------------------------------------------------------
# App Service Plan (B1 Linux)
# -----------------------------------------------------------------------
resource "azurerm_service_plan" "asp" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# -----------------------------------------------------------------------
# Linux Web App (.NET 10)
# -----------------------------------------------------------------------
resource "azurerm_linux_web_app" "webapp" {
  name                = var.webapp_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      dotnet_version = var.dotnet_version
    }
    always_on = false
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT   = "Development"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  https_only = true
}

# -----------------------------------------------------------------------
# User-Assigned Managed Identity (for GitHub Actions OIDC)
# -----------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "gha_identity" {
  name                = "gha-dotnet-deploy-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# -----------------------------------------------------------------------
# Role Assignment: Contributor at subscription scope
# Allows GitHub Actions to manage all resources in this subscription
# (needed for Terraform workflow to read/write all infra)
# -----------------------------------------------------------------------
resource "azurerm_role_assignment" "gha_subscription_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.gha_identity.principal_id
}

# -----------------------------------------------------------------------
# Federated Identity Credential (OIDC trust: GitHub Actions → Azure AD)
# Pinned to specific repo + environment for maximum security
# -----------------------------------------------------------------------
resource "azurerm_federated_identity_credential" "gha_oidc" {
  name                = "github-actions-oidc"
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.gha_identity.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:environment:${var.github_environment}"
}