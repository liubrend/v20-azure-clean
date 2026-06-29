# Remote state. The module generates the SQL admin password into Terraform state, so
# any non-throwaway use MUST keep state in a versioned, access-controlled Azure Storage
# container — never local (where it sits in plaintext on disk) and never in git.
#
# Set the values below, uncomment, then: terraform init -migrate-state
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "YOUR-TFSTATE-RG"
#     storage_account_name = "yourtfstateacct"   # versioned, restricted RBAC
#     container_name       = "tfstate"
#     key                  = "app/foundation.tfstate"
#   }
# }
