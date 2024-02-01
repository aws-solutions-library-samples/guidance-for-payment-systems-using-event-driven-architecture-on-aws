output "arn" {
  value       = aws_lambda_function.this.arn
  description = "Lambda function ARN"
}

output "name" {
  value       = local.function_name
  description = "Lambda function name"
}