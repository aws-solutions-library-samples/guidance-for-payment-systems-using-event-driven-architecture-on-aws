output "arn" {
  value       = aws_sqs_queue.this.arn
  description = "The ARN of the SQS queue"
}
