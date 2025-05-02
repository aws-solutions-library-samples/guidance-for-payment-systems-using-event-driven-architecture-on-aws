data "aws_caller_identity" "main" {}

resource "aws_iam_role" "this" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "pipes.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.main.account_id
        }
      }
    }
  })
}

resource "aws_iam_role_policy" "this" {
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams",
        ],
        Resource = [
          var.stream_arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "target" {
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents",
        ],
        Resource = [
          #"arn:aws:events:eu-west-1:926516876030:event-bus/default",
          var.eb_arn
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "kms" {
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = [
          "*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "invoke_dedup" {
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
        ],
        Resource = [
          var.lambda_arn
        ]
      },
    ]
  })
}

resource "aws_pipes_pipe" "this" {
  name     = "payment-input-enricher-pipe"
  role_arn = aws_iam_role.this.arn
  source   = var.stream_arn
  target   = var.eb_arn
  kms_key_identifier = var.kms_key_id
  #target = "arn:aws:events:eu-west-1:926516876030:event-bus/default"

  source_parameters {
    dynamodb_stream_parameters {
      batch_size                         = 1
      starting_position                  = "LATEST"
      maximum_record_age_in_seconds      = -1
      maximum_batching_window_in_seconds = 0
    }

    filter_criteria {
      filter {
        pattern = jsonencode({
          "eventSource" : ["aws:dynamodb"],
          "eventName" : ["INSERT", "UPDATE"]
        })
      }
    }
  }

  target_parameters {
    eventbridge_event_bus_parameters {
      detail_type = "TransactionAuthorized"
      source      = "octank.payments.posting"
    }
  }

  enrichment = var.lambda_arn
  #enrichment = "arn:aws:lambda:eu-west-1:926516876030:function:payments-visa-mock"
  enrichment_parameters {
    input_template = <<-EOT
    {
      "eventID": <$.eventID>,
      "eventVersion": <$.eventVersion>,
      "awsRegion": <$.awsRegion>,
      "eventName": <$.eventName>,
      "eventSourceARN": <$.eventSourceARN>,
      "eventSource": <$.eventSource>,
      "authCode": <$.dynamodb.Keys.auth.S>,
      "issuingCountryCode": <$.dynamodb.NewImage.IssuingCountryCode.S>,
      "PAN": <$.dynamodb.NewImage.PAN.S>,
      "billingAmount": <$.dynamodb.NewImage.BillingAmount.S>,
      "message": <$.dynamodb.NewImage.Message.S>,
      "transactionAmount": <$.dynamodb.NewImage.TransactionAmount.S>,
      "processingCode": <$.dynamodb.NewImage.ProcessingCode.S>,
      "panSequenceNumber": <$.dynamodb.NewImage.PANSequenceNumber.S>,
      "conversionRate": <$.dynamodb.NewImage.ConversionRate.S>,
      "acquiringCountryCode": <$.dynamodb.NewImage.AcquiringCountryCode.S>,
      "posEntryMode": <$.dynamodb.NewImage.POSEntryMode.S>,
      "messageType": <$.dynamodb.NewImage.MessageType.S>,
      "merchantType": <$.dynamodb.NewImage.MerchantType.S>,
      "posConditionCode": <$.dynamodb.NewImage.POSConditionCode.S>,
      "bitmap1": <$.dynamodb.NewImage.Bitmap1.S>,
      "bitmap2": <$.dynamodb.NewImage.Bitmap2.S>,
      "bitmap3": <$.dynamodb.NewImage.Bitmap3.S>,
      "dateTime": <$.dynamodb.NewImage.DateAndTime.S>,
      "expiryDate": <$.dynamodb.NewImage.ExpiryDate.S>,
      "systemTraceAuditNumber": <$.dynamodb.NewImage.SystemTraceAuditNumber.S>,
      "acquiringInstitutionIdCode": <$.dynamodb.NewImage.AcquiringInstitutionIDCode.S>,
      "forwardingInstitutionIdCode": <$.dynamodb.NewImage.ForwardingInstitutionIDCode.S>,
      "sequenceNumber": <$.dynamodb.NewImage.SequenceNumber.S>
    }
    EOT
  }

}
