# tf-reference-layouts
Cloud Infra reference layouts 


# AWS

## Configure the provider

- Create a `provider.tf` file in the `aws/` dir with the following:
  ```
  terraform {
    required_version = ">= 1.0.0"

    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 4.30"
      }
    }

    backend "local" {
      path = "terraform.tfstate"
    }
  }

  provider "aws" {
    shared_config_files       = ["$HOME/.aws/config"]
    shared_credentials_files  = ["$HOME/.aws/credentials"]
    profile                   = "<aws-profile-name>"
    region                    = "ap-south-1"
  }
  ```

  More details on [AWS provider's authentication and configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)