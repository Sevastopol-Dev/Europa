terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Central Transit Gateway Mesh
resource "aws_ec2_transit_gateway" "europa_tgw" {
  description = "Project Europa Ephemeral Transit Mesh Router"
  tags = {
    Name  = "europa-tgw-core"
    Epoch = var.epoch_id
  }
}

# Dynamic Active VPC (Blue/Green Parity Shift)
resource "aws_vpc" "europa_active_vpc" {
  cidr_block           = "10.199.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name  = "europa-vpc-${var.active_color}-epoch-${var.epoch_id}"
    Epoch = var.epoch_id
    Plane = var.active_color
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Dynamic Subnets driven by Brain Contract
resource "aws_subnet" "perimeter_ingress_alpha" {
  vpc_id            = aws_vpc.europa_active_vpc.id
  cidr_block        = var.europa_active_topology["perimeter_ingress_alpha"]
  availability_zone = "us-east-1a"

  tags = {
    Name  = "europa-sub-alpha-${var.active_color}"
    Role  = "perimeter_ingress_alpha"
    Epoch = var.epoch_id
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "perimeter_ingress_beta" {
  vpc_id            = aws_vpc.europa_active_vpc.id
  cidr_block        = var.europa_active_topology["perimeter_ingress_beta"]
  availability_zone = "us-east-1b"

  tags = {
    Name  = "europa-sub-beta-${var.active_color}"
    Role  = "perimeter_ingress_beta"
    Epoch = var.epoch_id
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "internal_routing_gateway" {
  vpc_id            = aws_vpc.europa_active_vpc.id
  cidr_block        = var.europa_active_topology["internal_routing_gateway"]
  availability_zone = "us-east-1a"

  tags = {
    Name  = "europa-sub-routing-gateway"
    Role  = "internal_routing_gateway"
    Epoch = var.epoch_id
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Deception Honeytoken Trap Subnet
resource "aws_subnet" "deception_honeytoken_tier" {
  vpc_id            = aws_vpc.europa_active_vpc.id
  cidr_block        = var.europa_active_topology["deception_honeytoken_tier"]
  availability_zone = "us-east-1b"

  tags = {
    Name       = "europa-sub-honeytoken-trap"
    Role       = "deception_honeytoken_tier"
    Honeytoken = var.active_honeytoken_trap
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Immutable Out-of-Band (OOB) Management Subnet (Prevents Lockouts)
resource "aws_subnet" "oob_management_plane" {
  vpc_id            = aws_vpc.europa_active_vpc.id
  cidr_block        = "10.199.255.0/28"
  availability_zone = "us-east-1a"

  tags = {
    Name = "europa-oob-immutable-management-subnet"
    Type = "OOB_ADMIN"
  }

  lifecycle {
    create_before_destroy = true
  }
}
