output "service_sg_id" {
  value = aws_security_group.service.id
}

output "codestar_connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}
