output "lambda_role_arn" {
  value = module.lambda_role.role_arn
}

output "lambda_security_group" {
  value = module.lambda_security_group.securityGroup_id
}
