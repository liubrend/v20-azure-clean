# Remote state. The module generates the DB password into Terraform state, so any
# non-throwaway use MUST keep state in a versioned, access-controlled GCS bucket —
# never local (where it sits in plaintext on disk) and never in git.
#
# Set the bucket below, uncomment, then: terraform init -migrate-state
#
# terraform {
#   backend "gcs" {
#     bucket = "YOUR-TF-STATE-BUCKET"   # versioned, restricted IAM
#     prefix = "app/foundation"
#   }
# }
