locals {
  env            = "dev"
  region         = "eu-central-1"
  name           = "opika"
  aws_account_id = data.aws_caller_identity.current.account_id
  num_of_subnets = min(length(data.aws_availability_zones.available.names), 2)
  azs            = slice(data.aws_availability_zones.available.names, 0, local.num_of_subnets)
  cidr           = "192.168.0.0/22"
  # azs                                = ["eu-central-1a", "eu-central-1b"]
  public_subnets                       = ["192.168.0.0/25", "192.168.0.128/25"]
  private_subnets                      = ["192.168.1.0/24", "192.168.2.0/24"]
  enable_nat_gateway                   = true
  single_nat_gateway                   = true
  one_nat_gateway_per_az               = false
  cluster_name                         = "${local.env}-${local.name}-${local.region}"
  cluster_version                      = "1.31"
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  default_security_group_ingress       = var.default_security_group_ingress
  default_security_group_egress        = var.default_security_group_egress
  aws_auth_users                       = []
  aws_auth_roles = [
    # {
    #   rolearn  = "arn:aws:iam::768088911524:role/AWSReservedSSO_AdministratorAccess_0dc87b5a7cfc809a"
    #   username = "admin"
    #   groups   = ["system:masters"]
    # }
  ]
  external-secret-ns      = "external-secrets"
  external-secret-enabled = false
  cert-manager-enabled    = false
}
