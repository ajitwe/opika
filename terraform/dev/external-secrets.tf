# # Policy
# data "aws_iam_policy_document" "external_secrets" {
#   count = local.external-secret-enabled ? 1 : 0
#   statement {
#     actions = [
#       "secretsmanager:GetResourcePolicy",
#       "secretsmanager:GetSecretValue",
#       "secretsmanager:DescribeSecret",
#       "secretsmanager:ListSecretVersionIds"
#     ]
#     resources = [
#       "*",
#     ]
#     effect = "Allow"
#   }

#   statement {
#     actions = [
#       "ssm:GetParameter*"
#     ]
#     resources = [
#       "*",
#     ]
#     effect = "Allow"
#   }

# }

# resource "aws_iam_policy" "external_secrets" {
#   depends_on  = [module.eks]
#   count       = local.external-secret-enabled ? 1 : 0
#   name        = "${local.cluster_name}-external-secrets"
#   path        = "/"
#   description = "Policy for external secrets service"

#   policy = data.aws_iam_policy_document.external_secrets[0].json
# }

# # Role
# data "aws_iam_policy_document" "external_secrets_assume" {
#   count = local.external-secret-enabled ? 1 : 0
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]

#     principals {
#       type        = "Federated"
#       identifiers = [module.eks.oidc_provider_arn]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"

#       values = [
#         "system:serviceaccount:${local.external-secret-ns}:${local.external-secret-ns}",
#       ]
#     }

#     effect = "Allow"
#   }
# }

# resource "aws_iam_role" "external_secrets" {
#   depends_on         = [module.eks]
#   count              = local.external-secret-enabled ? 1 : 0
#   name               = "${local.cluster_name}-external-secrets"
#   assume_role_policy = data.aws_iam_policy_document.external_secrets_assume[0].json
# }

# resource "aws_iam_role_policy_attachment" "external_secrets" {
#   depends_on = [module.eks]
#   count      = local.external-secret-enabled ? 1 : 0
#   role       = aws_iam_role.external_secrets[0].name
#   policy_arn = aws_iam_policy.external_secrets[0].arn
# }

