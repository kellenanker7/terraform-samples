output "endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

output "port" {
  value = aws_rds_cluster.aurora_cluster.port
}
