##################################################################################
# GET RESOURCE GROUP
##################################################################################

data "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
}


##################################################################################
# Function App
##################################################################################
resource "azurerm_application_insights" "logging" {
  name                = "${var.basename}-ai"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  application_type    = "web"
}

resource "azurerm_storage_account" "fxnstor" {
  name                     = "${var.basename}fx"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

resource "azurerm_service_plan" "fxnapp" {
  name                = "${var.basename}-plan"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "fxn" {
  name                      = var.basename
  location                  = var.location
  resource_group_name       = data.azurerm_resource_group.rg.name
  service_plan_id           = azurerm_service_plan.fxnapp.id
  storage_account_name       = azurerm_storage_account.fxnstor.name
  storage_account_access_key = azurerm_storage_account.fxnstor.primary_access_key

  site_config {}
}


##################################################################################
# Outputs
##################################################################################

resource "local_file" "app_deployment_script" {
  content  = <<CONTENT
#!/bin/bash

sed -i 's/STORAGEACCOUNTNAME/${azurerm_function_app.fxn.name}/g' file.txt
az functionapp config appsettings set -n ${azurerm_function_app.fxn.name} -g ${azurerm_resource_group.rg.name} --settings "APPINSIGHTS_INSTRUMENTATIONKEY=""${azurerm_application_insights.logging.instrumentation_key}""" > /dev/null
cd ../src ; func azure functionapp publish ${azurerm_function_app.fxn.name} --worker-runtime python ; cd ../terraform
CONTENT
  filename = "./deploy_app.sh"
}