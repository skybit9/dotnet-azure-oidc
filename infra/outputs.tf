# -----------------------------------------------------------------------
# Outputs — use these to populate GitHub Actions secrets/vars
# -----------------------------------------------------------------------

output "webapp_name" {
  description = "Web App name → set as AZURE_WEBAPP_NAME in GitHub Actions env"
  value       = azurerm_linux_web_app.webapp.name
}

output "webapp_url" {
  description = "Default hostname of the deployed web app"
  value       = "https://${azurerm_linux_web_app.webapp.default_hostname}"
}

output "managed_identity_client_id" {
  description = "Client ID → set as AZURE_CLIENT_ID GitHub secret"
  value       = azurerm_user_assigned_identity.gha_identity.client_id
}

output "tenant_id" {
  description = "Tenant ID → set as AZURE_TENANT_ID GitHub secret"
  value       = azurerm_user_assigned_identity.gha_identity.tenant_id
}

output "subscription_id" {
  description = "Subscription ID → set as AZURE_SUBSCRIPTION_ID GitHub secret"
  value       = azurerm_linux_web_app.webapp.id
  # Extract subscription from resource ID: /subscriptions/<sub-id>/...
}

output "oidc_subject_claim" {
  description = "Subject claim configured in federated credential"
  value       = azurerm_federated_identity_credential.gha_oidc.subject
}
