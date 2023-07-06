terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
}

provider "azurerm" {
    subscription_id = "27797fca-63b0-46fd-87c7-0757c81e041a"
    client_id ="80673a22-4b8c-44e8-b1a1-72f9e3c2a37e"
    client_secret = "z8p8Q~a3Z8ZoISvXbmySld7MdAC1XteBuuzROcDo"
    tenant_id = "2c5efac5-c4bd-4292-a494-ff1758054b2c"
    features {
      
    }
}

resource "azurerm_resource_group" "project_rg" {
  name     = "project_rg"
  location = "UK South"
}
resource "azurerm_service_plan" "project_appplan" {
  name                = "project-appserviceplan"
  location            = azurerm_resource_group.project_rg.location
  resource_group_name = azurerm_resource_group.project_rg.name
  os_type = "Windows"
  sku_name = "S1"

}
resource "azurerm_cosmosdb_account" "projectcosmosdbacct" {
  name                = "projectcosmosdbacct"
  location = azurerm_resource_group.project_rg.location
  resource_group_name = azurerm_resource_group.project_rg.name
  offer_type = "Standard"
  enable_automatic_failover = false
  kind = "MongoDB"

   capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  capabilities {
    name = "EnableMongo"
  }
  
  consistency_policy {
    consistency_level       = "Strong"
  }

  geo_location {
    location          = azurerm_resource_group.project_rg.location
    failover_priority = 0
  }
}
data "azurerm_cosmosdb_account" "projectcosmosdbacct"{
  name = azurerm_cosmosdb_account.projectcosmosdbacct.name
  resource_group_name = azurerm_resource_group.project_rg.name
}
resource "azurerm_cosmosdb_mongo_database" "project_cosmosdb" {
  name                = "project_cosmosdb"
  resource_group_name = data.azurerm_cosmosdb_account.projectcosmosdbacct.resource_group_name
  account_name        = data.azurerm_cosmosdb_account.projectcosmosdbacct.name
  throughput          = 400
  depends_on = [ azurerm_cosmosdb_account.projectcosmosdbacct ]
}
resource "azurerm_windows_web_app" "MyNodeJsApp" {
  name                = "MyNodeJsAppproject"
  resource_group_name = azurerm_resource_group.project_rg.name
  location            = azurerm_service_plan.project_appplan.location
  service_plan_id     = azurerm_service_plan.project_appplan.id
  
  site_config {
    application_stack {
    current_stack = "node"
    node_version = "16-LTS"
  }
  }
  
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "16-LTS"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = true
    "DATABASE_NAME" = azurerm_cosmosdb_mongo_database.project_cosmosdb.name
    "DATABASE_URL" = azurerm_cosmosdb_account.projectcosmosdbacct.connection_strings[0]  //"mongodb://projectcosmosdbacct:C4yLtHSN82y5WSQK5mnpob5zxfWmnzzOwYJWxXYbHkkyCQMz8YLJTfoqc3nWF5CRQsp9E7fGyWbVACDb2wx3Wg==@projectcosmosdbacct.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@projectcosmosdbacct@"
  }
  
      
  depends_on = [ azurerm_service_plan.project_appplan ]
}



resource "azurerm_cosmosdb_mongo_collection" "projectmongoCollection" {
  name                = "projectmongoCollection"
  resource_group_name = data.azurerm_cosmosdb_account.projectcosmosdbacct.resource_group_name
  account_name        = data.azurerm_cosmosdb_account.projectcosmosdbacct.name
  database_name       = azurerm_cosmosdb_mongo_database.project_cosmosdb.name

  default_ttl_seconds = "777"
  shard_key           = "uniqueKey"
  throughput          = 400

  index {
    keys   = ["_id"]
    unique = true
  }
}

/*resource "azurerm_app_service" "project_appservice" {
  name                = "appserviceproject"
  location            = azurerm_resource_group.project_rg.location
  resource_group_name = azurerm_resource_group.project_rg.name
  app_service_plan_id = azurerm_service_plan.project_appplan.id
  
  
  app_settings = {
    "DATABASE_NAME" = azurerm_cosmosdb_mongo_database.project_cosmosdb.name
    
  }
   
}*/




resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id   = azurerm_windows_web_app.MyNodeJsApp.id
  repo_url = "https://github.com/db9crt/node-mongodb-app"
  branch   = "main"
  github_action_configuration {
    generate_workflow_file = true
    code_configuration {
      runtime_stack   = "node"
      runtime_version = "16.0.0"

    }
  }
  depends_on = [ azurerm_source_control_token.dobble_token ]
}
  resource "azurerm_source_control_token" "dobble_token" {
  type  = "GitHub"
  token = "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"
}