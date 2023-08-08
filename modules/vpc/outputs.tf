output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = [ for subnet in aws_subnet.public : subnet.id ]
}

output "main_route_table_id" {
  value = aws_route_table.main.id
}
