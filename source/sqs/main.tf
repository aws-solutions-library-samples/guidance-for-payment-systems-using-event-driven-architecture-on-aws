locals {
  queue_name = "${var.project_name}-${var.name}"
  redrive_policy = var.is_dlq ? null : jsonencode({
    "deadLetterTargetArn" = var.dead_letter_queue_arn
    "maxReceiveCount"     = var.max_receive_count
  })
  #validate_redrive_policy = (!var.is_dlq && var.dead_letter_queue_arn == null) ? tobool("Please provide dead_letter_queue_arn or change is_dlq to true.") : true
}

resource "aws_sqs_queue" "this" {
  name                       = local.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  #redrive_policy             = local.redrive_policy
  redrive_policy              = var.is_dlq ? null : local.redrive_policy
  sqs_managed_sse_enabled     = true
  fifo_queue                  = true
  content_based_deduplication = true
  policy = length(var.publisher_arns) == 0 ? null : jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = ["sqs:SendMessage"]
      Effect    = "Allow"
      Principal = {
        Service = ["events.amazonaws.com"]
      }
      Resource  = "arn:aws:sqs:*:*:${local.queue_name}"
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = var.publisher_arns
        }
      }
    }]
  })

  tags = {
    Name = local.queue_name
  }
}