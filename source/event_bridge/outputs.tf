output "arn" {
  value       = aws_cloudwatch_event_bus.this.arn
  description = "The ARN of the SQS queue"
}

output "posting_rule_arn" {
  value       = aws_cloudwatch_event_rule.posting.arn
  description = "The ARN of the Posting EB Rule"
}

output "posted_rule_arn" {
  value       = aws_cloudwatch_event_rule.posted.arn
  description = "The ARN of the Posted EB Rule"
}