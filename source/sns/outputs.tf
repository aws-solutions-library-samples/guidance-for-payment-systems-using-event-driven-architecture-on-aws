output "arn" {
  value       = aws_sns_topic.payment_posting_failure.arn
  description = "The ARN of the SNS queue"
}