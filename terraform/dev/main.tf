data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

# # terraform backend state
# terraform {
#   backend "s3" {
#     bucket         = "opika-ajit-tfstate"
#     key            = "dev/state"
#     dynamodb_table = "dev-terraform-state-lock"
#     encrypt        = true
#   }
# }

# Create s3 bucket for terraform state
# module "s3_tf_state" {
#   source      = "../modules/s3"
#   bucket_name = "opika-ajit-tfstate"
# }

# Create a dynamoDB for key-value storage
# module "dynamodb_table" {
#   source         = "../modules/dynamo_db"
#   name           = "${local.env}-terraform-state-lock"
#   hash_key       = "LockID"
#   table_class    = "STANDARD"
#   billing_mode   = "PROVISIONED"
#   write_capacity = 5
#   read_capacity  = 5

#   attributes = [
#     {
#       name = "LockID"
#       type = "S"
#     }
#   ]
# }

variable "default_security_group_egress" {
  description = "List of maps of egress rules to set on the default security group"
  type        = list(map(string))
  default = [
    {
      cidr_blocks = "172.27.224.0/20"
      description = "default_security_group_egress"
      from_port   = 0
      protocol    = "-1"
      self        = false
      to_port     = 0
    }
  ]
}

variable "default_security_group_ingress" {
  description = "List of maps of egress rules to set on the default security group"
  type        = list(map(string))
  default = [
    {
      cidr_blocks = "172.27.224.0/20"
      description = "default_security_group_ingress"
      from_port   = 0
      protocol    = "-1"
      self        = true
      to_port     = 0
    }
  ]
}

# Create VPC using Terraform Module
# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 5.1.1"

#   # Details
#   name            = "${local.env}-vpc"
#   cidr            = local.cidr
#   azs             = local.azs
#   public_subnets  = local.public_subnets
#   private_subnets = local.private_subnets

#   # NAT Gateways - Outbound Communication
#   enable_nat_gateway     = local.enable_nat_gateway
#   single_nat_gateway     = local.single_nat_gateway
#   one_nat_gateway_per_az = local.one_nat_gateway_per_az

#   # DNS Parameters in VPC
#   enable_dns_hostnames = true
#   enable_dns_support   = true

#   # Manage so we can name
#   manage_default_network_acl     = true
#   default_network_acl_tags       = { Name = "${local.cluster_name}-default" }
#   manage_default_route_table     = true
#   default_route_table_tags       = { Name = "${local.cluster_name}-default" }
#   manage_default_security_group  = true
#   default_security_group_tags    = { Name = "${local.cluster_name}-default" }
#   default_security_group_ingress = var.default_security_group_ingress
#   default_security_group_egress  = var.default_security_group_egress

#   # Additional tags for the public subnets
#   public_subnet_tags = {
#     "kubernetes.io/role/elb"                      = 1
#     "kubernetes.io/cluster/${local.cluster_name}" = "shared"
#   }

#   # Additional tags for the private subnets
#   private_subnet_tags = {
#     # Name = "${local.env}-private-subnet"
#     "kubernetes.io/role/internal-elb"             = 1
#     "kubernetes.io/cluster/${local.cluster_name}" = "shared"
#   }

#   # Instances launched into the Public subnet should be assigned a public IP address.
#   # Specify true to indicate that instances launched into the subnet should be assigned a public IP address
#   map_public_ip_on_launch = true

#   enable_flow_log                                 = false
#   create_flow_log_cloudwatch_log_group            = false
#   create_flow_log_cloudwatch_iam_role             = false
#   flow_log_traffic_type                           = "REJECT"
#   flow_log_cloudwatch_log_group_retention_in_days = 7

# }