
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
    kubectl = {
      source = "alekc/kubectl"
      # version = ">= 2.0.3"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      # version = ">= 2.10"
    }
  }
}
