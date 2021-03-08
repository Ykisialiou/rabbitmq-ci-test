provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "al_devops_test" {
  name     = "myaks-resource-group"
  location = "eastus2"
}

module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.al_devops_test.name
  address_space       = "10.0.0.0/16"
  subnet_prefixes     = ["10.0.1.0/24"]
  subnet_names        = ["aks-net"]
  depends_on          = [azurerm_resource_group.al_devops_test]
  tags                = {
    "CreatedBy" : "ekiselev",
    "Env" : "al-devops-test",
    "Name" : "al-devops-test-ekiselev-aks-net"
  }
}

data "azuread_group" "aks_cluster_admins" {
  display_name = "AKS-cluster-admins"
}

module "aks" {
  source                           = "Azure/aks/azurerm"
  resource_group_name              = azurerm_resource_group.al_devops_test.name
  client_id                        = var.principal_client_appid
  client_secret                    = var.principal_client_password
  kubernetes_version               = "1.19.7"
  orchestrator_version             = "1.19.7"
  prefix                           = "al-devops-test"
  network_plugin                   = "azure"
  vnet_subnet_id                   = module.network.vnet_subnets[0]
  os_disk_size_gb                  = 50
  sku_tier                         = "Paid" # defaults to Free
  enable_role_based_access_control = true
  rbac_aad_admin_group_object_ids  = [data.azuread_group.aks_cluster_admins.id]
  rbac_aad_managed                 = true
  private_cluster_enabled          = false
  enable_http_application_routing  = true
  enable_azure_policy              = true
  enable_auto_scaling              = false 
  agents_count                     = 2 
  agents_max_pods                  = 100
  agents_pool_name                 = "exnodepool"
  agents_availability_zones        = ["1", "2"]
  agents_type                      = "VirtualMachineScaleSets"
  enable_log_analytics_workspace   = false 
  
  agents_labels = {
    "nodepool" : "defaultnodepool"
  }


  tags = {
    "CreatedBy" : "ekiselev",
    "Env" : "al-devops-test",
    "Name" : "al-devops-test-ekiselev-aks"
  }


  agents_tags = {
    "CreatedBy" : "ekiselev",
    "Env" : "al-devops-test",
    "Name" : "al-devops-test-ekiselev-aks"
  }


  network_policy                 = "azure"
  net_profile_dns_service_ip     = "10.200.0.10"
  net_profile_docker_bridge_cidr = "170.10.0.1/16"
  net_profile_service_cidr       = "10.200.0.0/16"

  depends_on = [module.network]
}
