# Create EKS using Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.18.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  enable_irsa     = true

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = local.cluster_endpoint_public_access_cidrs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true

  aws_auth_users = local.aws_auth_users
  aws_auth_roles = local.aws_auth_roles

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description = "Private subnets HTTPS ingress"
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = local.private_subnets
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_https_443 = {
      description = "Private subnets HTTPS ingress"
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = local.private_subnets
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      # additional                         = aws_iam_policy.node_additional.arn
    }
  }

  eks_managed_node_groups = {

    infra = {
      name              = "${local.cluster_name}-infra-ng"
      use_name_prefix   = false
      enable_monitoring = true
      min_size          = 1
      max_size          = 2
      desired_size      = 1

      instance_types = ["t3.micro"]
      capacity_type  = "ON_DEMAND"
      update_config  = { max_unavailable = 1 }

      launch_template_name            = "${local.cluster_name}-infra-ng"
      launch_template_use_name_prefix = false
      launch_template_description     = "Custom launch template for ${local.cluster_name}-infra-ng EKS managed group"

      iam_role_name            = "${local.cluster_name}-infra-ng"
      iam_role_use_name_prefix = false

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }
        }
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }
        }
      }

      labels = {
        "nodegroup" = "${local.cluster_name}-infra"
      }

      network_interfaces = [{
        delete_on_termination       = true
        associate_public_ip_address = false
      }]

      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
      }
    }

  }

}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  aliases               = ["eks/${local.cluster_name}-key"]
  description           = "${local.cluster_name} cluster encryption key"
  enable_default_policy = true
  key_owners            = [data.aws_caller_identity.current.arn]
}

module "eks_blueprints_addons" {
  depends_on = [module.eks, aws_iam_role.external_secrets]
  source     = "aws-ia/eks-blueprints-addons/aws"
  version    = "~> 1.11.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    # aws-ebs-csi-driver = {
    #   most_recent = true
    #   # addon_version            = "v1.29.1-eksbuild.1"
    #   service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    # }
    # coredns = {
    #   most_recent = true
    #   # addon_version = "v1.11.1-eksbuild.6"
    #   timeouts = {
    #     create = "25m"
    #     delete = "10m"
    #   }
    # }
    vpc-cni = {
      most_recent = true
      # addon_version = "v1.18.0-eksbuild.1"
    }
    kube-proxy = {
      # most_recent              = true
      # addon_version            = "v1.29.3-eksbuild.2"
      service_account_role_arn = module.adot_irsa.iam_role_arn
    }
    # aws-guardduty-agent = {}
  }

  enable_aws_load_balancer_controller = false
  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
    }]
  }


  enable_argocd                                = false
  enable_aws_cloudwatch_metrics                = false
  enable_cluster_autoscaler                    = true
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true
  enable_kube_prometheus_stack                 = false

  enable_external_secrets = local.external-secret-enabled
  external_secrets = {
    name             = "external-secrets"
    chart_version    = "0.9.19"
    repository       = "https://charts.external-secrets.io"
    namespace        = local.external-secret-ns
    create_namespace = true
    values = [templatefile("${path.module}/templates/external-secrets.yaml",
      {
        external_secrets_role_arn = aws_iam_role.external_secrets[0].arn
      })
    ]
  }

  enable_gatekeeper    = false
  enable_ingress_nginx = false

  enable_metrics_server    = true
  enable_vpa               = false
  enable_fargate_fluentbit = false
  enable_aws_for_fluentbit = false

}

module "adot_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${local.env}-adot-"

  role_policy_arns = {
    prometheus = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
    xray       = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["opentelemetry-operator-system:opentelemetry-operator"]
    }
  }
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${local.env}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

}

# resource "aws_efs_file_system" "efs" {
#   creation_token = "eks-efs"
#   tags = {
#     Name = "eks-efs"
#   }
# }

# resource "aws_efs_mount_target" "efs_mount" {
#   count           = length(module.vpc.private_subnets)
#   file_system_id  = aws_efs_file_system.efs.id
#   subnet_id       = module.vpc.private_subnets[count.index]
#   security_groups = [module.eks.cluster_security_group_id]
# }

