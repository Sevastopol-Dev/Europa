terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "europa-state-lock-vault"
    key            = "core/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "europa-state-locks"
  }
}

provider "aws" {
  region = "us-east-1"
}

module "europa_network" {
  source                 = "../modules/network"
  epoch_id               = var.epoch_id
  active_color           = var.active_color
  active_honeytoken_trap = var.active_honeytoken_trap
  europa_active_topology = var.europa_active_topology
}

module "europa_identity" {
  source                    = "../modules/identity"
  epoch_id                  = var.epoch_id
  ephemeral_pipeline_policy = var.ephemeral_pipeline_policy
  quarantine_honeybucket    = var.quarantine_honeybucket
}
