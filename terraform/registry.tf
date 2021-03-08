resource "azurerm_container_registry" "acr" {
  name                     = "rabbitmqAlDevopsTest"
  resource_group_name      = azurerm_resource_group.al_devops_test.name
  location                 = azurerm_resource_group.al_devops_test.location
  sku                      = "Premium"
  admin_enabled            = true 
}
