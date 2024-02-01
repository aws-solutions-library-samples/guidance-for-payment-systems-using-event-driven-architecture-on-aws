data "aws_caller_identity" "current" {}

locals {
  eb_archive = {
    "posting" = {
      description    = "Posting Archive",
      retention_days = 1
      event_pattern = jsonencode(
        {
          "source" : ["posting.data"]

        }
      )
    }
    "posted" = {
      description    = "Posted Archive",
      retention_days = 1
      event_pattern = jsonencode(
        {
          "source" : ["posted.data"]

        }
      )
    }
    "auth" = {
      description    = "Auth Archive",
      retention_days = 1
      event_pattern = jsonencode(
        {
          "account" : [data.aws_caller_identity.current.account_id]

        }
      )
    }
    "enriched" = {
      description    = "Enrich Archive",
      retention_days = 1
      event_pattern = jsonencode(
        {
          "source" : ["enriched.data"]

        }
      )
    }
  }
}
resource "aws_cloudwatch_event_bus" "this" {
  name = var.event_bridge_name
}

resource "aws_schemas_discoverer" "this" {

  source_arn  = aws_cloudwatch_event_bus.this.arn
  description = "Enable Schema Discovery"

}

resource "aws_cloudwatch_event_archive" "this" {
  for_each         = local.eb_archive
  name             = each.key
  event_source_arn = aws_cloudwatch_event_bus.this.arn

  description    = lookup(each.value, "description", null)
  event_pattern  = lookup(each.value, "event_pattern", null)
  retention_days = lookup(each.value, "retention_days", null)
}

resource "aws_sqs_queue" "dlq" {
  name                        = "paymentsdlq"
  fifo_queue                  = false
  content_based_deduplication = false
}

resource "aws_cloudwatch_event_rule" "posting" {
  name = "payments-posting-rule"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["TransactionPostingApproved"]
    }
  )
}

resource "aws_cloudwatch_event_target" "posting_queue" {
  rule = aws_cloudwatch_event_rule.posting.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  #arn  = "arn:aws:sqs:eu-west-2:926516876030:PostingQueue.fifo"
  arn = var.posting_queue_arn
  sqs_target {
    message_group_id = "posting-queue"
  }
  dead_letter_config {
    arn = aws_sqs_queue.dlq.arn
  }
}

# resource "aws_cloudwatch_event_target" "posting_archive" {
#   rule      = aws_cloudwatch_event_rule.posting.id
#   target_id = "3"
#   arn       = aws_cloudwatch_event_archive.this["posting"].arn
#   #role_arn  = aws_iam_role.this.arn
# }

resource "aws_cloudwatch_event_target" "firehose_posting" {
  rule      = aws_cloudwatch_event_rule.posting.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id = "2"
  arn       = aws_kinesis_firehose_delivery_stream.this.arn
  role_arn  = aws_iam_role.this.arn
}

resource "aws_cloudwatch_event_rule" "authrule" {
  name = "payments-auth-rule"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["TransactionAuthorized"]
    }
  )
}

resource "aws_cloudwatch_event_target" "auth_lambda" {
  rule = aws_cloudwatch_event_rule.authrule.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn = var.enrich_lambda_arn
  dead_letter_config {
    arn = aws_sqs_queue.dlq.arn
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = "payments-enrich"
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.authrule.arn
}

# resource "aws_cloudwatch_event_target" "auth_archive" {
#   rule      = aws_cloudwatch_event_rule.authrule.id
#   target_id = "3"
#   arn       = aws_cloudwatch_event_archive.this["auth"].arn
#   #role_arn  = aws_iam_role.this.arn
# }

resource "aws_cloudwatch_event_rule" "enriched" {
  name = var.event_rule_name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["TransactionEnriched"]
    }
  )
}

resource "aws_cloudwatch_event_target" "sfn" {
  rule = aws_cloudwatch_event_rule.enriched.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn      = var.state_machine_arn
  role_arn = aws_iam_role.this.arn
  
}

# resource "aws_cloudwatch_event_target" "enriched_archive" {
#   rule      = aws_cloudwatch_event_rule.enriched.id
#   target_id = "3"
#   arn       = aws_cloudwatch_event_archive.this["enriched"].arn
# }

resource "aws_cloudwatch_event_rule" "foreign" {
  name = "foreign-transactions-posted"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["ForeignTransactionFound"]
    }
  )
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/events/ForeignTransactions"

}

data "aws_iam_policy_document" "cwlogs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = [aws_cloudwatch_log_group.this.arn]

    principals {
      identifiers = ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_document = data.aws_iam_policy_document.cwlogs.json
  policy_name     = "foreign-log-publishing-policy"
}

resource "aws_cloudwatch_event_target" "foreign_cw" {
  rule      = aws_cloudwatch_event_rule.foreign.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id = "5"
  arn       = aws_cloudwatch_log_group.this.arn
}

resource "aws_cloudwatch_event_rule" "cctran" {
  name = "cc-transactions-posted"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["CurrencyConversionTransactionFound"]
    }
  )
}

resource "aws_cloudwatch_log_group" "cctran" {
  name = "/aws/events/CurrencyConversionTransaction"

}

data "aws_iam_policy_document" "cwlogs_cctran" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = [aws_cloudwatch_log_group.cctran.arn]

    principals {
      identifiers = ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "cctran" {
  policy_document = data.aws_iam_policy_document.cwlogs_cctran.json
  policy_name     = "cctran-log-publishing-policy"
}

resource "aws_cloudwatch_event_target" "cctran_cw" {
  rule      = aws_cloudwatch_event_rule.cctran.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id = "6"
  arn       = aws_cloudwatch_log_group.cctran.arn
}

resource "aws_cloudwatch_event_rule" "merchant" {
  name = "cc-transactions-posted"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["WarningMerchantTypeTransactionFound"]
    }
  )
}

resource "aws_cloudwatch_log_group" "merchant" {
  name = "WarningMerchantTypeTransaction"

}

resource "aws_cloudwatch_event_target" "merchant_cw" {
  rule      = aws_cloudwatch_event_rule.merchant.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id = "7"
  arn       = aws_cloudwatch_log_group.merchant.arn
}

resource "aws_cloudwatch_event_rule" "posted" {
  name = "posted-payments-rule"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern = jsonencode(

    {
      "source" : [{ "prefix": "octank.payments.posting" }],
      "detail-type" : ["TransactionPosted"]
    }
  )
}

resource "aws_cloudwatch_event_target" "posted_queue" {
  rule = aws_cloudwatch_event_rule.posted.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn = var.posted_queue_arn
  
  sqs_target {
    message_group_id = "posted-queue"
  }
  dead_letter_config {
    arn = aws_sqs_queue.dlq.arn
  }
}

# resource "aws_cloudwatch_event_target" "posted_archive" {
#   rule      = aws_cloudwatch_event_rule.posted.id
#   target_id = "8"
#   arn       = aws_cloudwatch_event_archive.this["posted"].arn
#   #role_arn  = aws_iam_role.this.arn
# }

resource "aws_s3_bucket" "this" {

  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "this" {

  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "this" {

  bucket     = aws_s3_bucket.this.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.this]
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "payments-firehose-delivery-stream"
  destination = "extended_s3"
  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.this.arn
  }
}

resource "aws_iam_role" "firehose" {
  name_prefix = "payments"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "firehose_s3" {
  name_prefix = "payments"

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
        ],
        "Resource": [
            "${aws_s3_bucket.this.arn}",
            "${aws_s3_bucket.this.arn}/*"
        ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_s3" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose_s3.arn
}