# Configuration du provider AWS

provider "aws" {
  region = var.aws_region
}


# Autres fournisseurs:

# Azure
#provider "azurerm" {
#  features {}
#}

# Google Cloud
#provider "google" {
#  project = "mon-projet"
#  region  = "us-central1"
#}
