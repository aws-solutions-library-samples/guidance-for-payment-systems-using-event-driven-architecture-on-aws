provider "aws" {
  region = var.region
}

provider "random" {}

locals {
  definition_template = <<EOF
{
  "Comment": "State machine implementing sample business rules for building cross-platform event-driven payment systems on AWS guidance",
  "StartAt": "ValidateTransaction",
  "States": {
    "ValidateTransaction": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.detail.issuingCountryCode",
          "StringEquals": "",
          "Next": "Publish Posting Failure"
        }
      ],
      "Default": "CheckForeignTransaction"
    },
    "Publish Posting Failure": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "Message.$": "$",
        "TopicArn": "${module.sns.arn}"
      },
      "End": true
    },
    "CheckForeignTransaction": {
      "Comment": "A Choice state adds branching logic to a state machine. Choice rules can implement 16 different comparison operators, and can be combined using And, Or, and Not",
      "Type": "Choice",
      "Choices": [
        {
          "Not": {
            "Variable": "$.detail.billingAmount",
            "StringEqualsPath": "$.detail.transactionAmount"
          },
          "Next": "TriggerForeignTransactionRule"
        }
      ],
      "Default": "CheckConversionRate"
    },
    "TriggerForeignTransactionRule": {
      "Type": "Task",
      "Next": "CheckConversionRate",
      "Parameters": {
        "Entries": [
          {
            "DetailType": "ForeignTransactionFound",
            "EventBusName": "payments",
            "Source": "octank.payments.posting.rules",
            "Detail": {
              "original_message.$": "$.original_message",
              "iban.$": "$.iban",
              "account_type.$": "$.account_type",
              "has_holds.$": "$.has_holds",
              "suspense_account.$": "$.suspense_account",
              "head_office_account.$": "$.head_office_account",
              "tax_category.$": "$.tax_category",
              "billingAmount.$": "$.billingAmount",
              "transactionAmount.$": "$.transactionAmount",
              "conversionRate.$": "$.conversionRate",
              "merchantType.$": "$.merchantType",
              "issuingCountryCode.$": "$.issuingCountryCode",
              "authCode.$": "$.authCode",
              "acquiringCountryCode.$": "$.acquiringCountryCode",
              "posEntryMode.$": "$.posEntryMode",
              "systemTraceAuditNumber.$": "$.systemTraceAuditNumber"
            }
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:eventbridge:putEvents",
      "InputPath": "$.detail",
      "ResultPath": null
    },
    "CheckConversionRate": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.detail.conversionRate",
          "StringEquals": "1",
          "Next": "TriggerConversionRateRule"
        }
      ],
      "Default": "CheckMerchantType"
    },
    "TriggerConversionRateRule": {
      "Type": "Task",
      "Parameters": {
        "Entries": [
          {
            "DetailType": "CurrencyConversionTransactionFound",
            "EventBusName": "payments",
            "Source": "octank.payments.posting.rules",
            "Detail": {
              "original_message.$": "$.original_message",
              "iban.$": "$.iban",
              "account_type.$": "$.account_type",
              "has_holds.$": "$.has_holds",
              "suspense_account.$": "$.suspense_account",
              "head_office_account.$": "$.head_office_account",
              "tax_category.$": "$.tax_category",
              "billingAmount.$": "$.billingAmount",
              "transactionAmount.$": "$.transactionAmount",
              "conversionRate.$": "$.conversionRate",
              "merchantType.$": "$.merchantType",
              "issuingCountryCode.$": "$.issuingCountryCode",
              "authCode.$": "$.authCode",
              "acquiringCountryCode.$": "$.acquiringCountryCode",
              "posEntryMode.$": "$.posEntryMode",
              "systemTraceAuditNumber.$": "$.systemTraceAuditNumber"
            }
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:eventbridge:putEvents",
      "Next": "CheckMerchantType",
      "ResultPath": null,
      "InputPath": "$.detail"
    },
    "CheckMerchantType": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.detail.merchantType",
          "StringEquals": "AAFF",
          "Next": "TriggerMerchantRule"
        }
      ],
      "Default": "PostTransactionProcessedEvent"
    },
    "TriggerMerchantRule": {
      "Type": "Task",
      "Parameters": {
        "Entries": [
          {
            "DetailType": "WarningMerchantTypeTransactionFound",
            "EventBusName": "payments",
            "Source": "octank.payments.posting.rules",
            "Detail": {
              "original_message.$": "$.original_message",
              "iban.$": "$.iban",
              "account_type.$": "$.account_type",
              "has_holds.$": "$.has_holds",
              "suspense_account.$": "$.suspense_account",
              "head_office_account.$": "$.head_office_account",
              "tax_category.$": "$.tax_category",
              "billingAmount.$": "$.billingAmount",
              "transactionAmount.$": "$.transactionAmount",
              "conversionRate.$": "$.conversionRate",
              "merchantType.$": "$.merchantType",
              "issuingCountryCode.$": "$.issuingCountryCode",
              "authCode.$": "$.authCode",
              "acquiringCountryCode.$": "$.acquiringCountryCode",
              "posEntryMode.$": "$.posEntryMode",
              "systemTraceAuditNumber.$": "$.systemTraceAuditNumber"
            }
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:eventbridge:putEvents",
      "Next": "PostTransactionProcessedEvent",
      "InputPath": "$.detail",
      "ResultPath": null
    },
    "PostTransactionProcessedEvent": {
      "Type": "Task",
      "End": true,
      "Parameters": {
        "Entries": [
          {
            "DetailType": "TransactionPostingApproved",
            "EventBusName": "payments",
            "Source": "octank.payments.posting.rules",
            "Detail": {
              "original_message": "1313231233",
              "iban": "GB137883523981",
              "account_type": "Business",
              "has_holds": true,
              "suspense_account": "SA732688",
              "head_office_account": "HO182786",
              "tax_category": "Other",
              "billingAmount": "2000",
              "transactionAmount": "2000",
              "conversionRate": "1",
              "merchantType": "AACC",
              "issuingCountryCode": "840",
              "authCode": "503",
              "acquiringCountryCode": "840",
              "posEntryMode": "1",
              "systemTraceAuditNumber": "1"
            }
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:eventbridge:putEvents"
    }
  }
}
EOF
}


#Part-1::: In this part set up eMock Auth into Dynamo DB table and set up a DB stream
module "mock_lambda" {
  source       = "./lambda_function"
  lambda_name  = "visa-mock"
  project_name = "payments"
  timeout      = 120
  memory_size  = 2048
  policies     = []

}

module "dynamodb" {
  source = "./dynamodb"

}

module "event_bridge" {
  source            = "./event_bridge"
  event_bridge_name = var.event_bridge_name
  posting_queue_arn = module.posting_queue.arn
  posted_queue_arn  = module.posted_queue.arn
  enrich_lambda_arn = module.enrich_lambda.arn
  state_machine_arn = module.sfn.state_machine_arn
  #bucket_name       = "${var.root_bucket_name}-${random_string.this.result}"

}

module "dedup_ddb_table" {
  source = "./dynamodb"
  name   = "transaction_dupcheck_log"
  attributes = [
    {
      name = "key"
      type = "S"
    }
  ]
  hash_key       = "key"
  stream_enabled = false
}

module "dedup_lambda" {
  source       = "./lambda_function"
  lambda_name  = "dedup"
  project_name = "payments"
  timeout      = 120
  memory_size  = 2048
  policies     = []
  environment_variables = {
    WINDOW_DURATION_SECONDS = 300
  }
}

module "event-pipes" {
  source                   = "./event-pipes"
  stream_arn               = module.dynamodb.stream_arn
  eb_arn                   = module.event_bridge.arn
  lambda_arn               = module.dedup_lambda.arn
  target_event_detail_type = "TransactionAuthorized"
  target_event_source      = "octank.payments.posting.visaIngest"
}

module "enrich_lambda" {
  source       = "./lambda_function"
  lambda_name  = "enrich"
  project_name = "payments"
  timeout      = 120
  memory_size  = 2048
  policies = [
    {
      Action = [
        "events:PutEvents",
      ]
      Effect   = "Allow"
      Resource = module.event_bridge.arn
    }
  ]
  environment_variables = {
    EVENT_BUS_NAME = var.event_bridge_name
  }
}

module "posting_lambda" {
  source       = "./lambda_function"
  lambda_name  = "posting"
  project_name = "payments"
  timeout      = 120
  memory_size  = 2048
  policies = [
    {
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Effect   = "Allow"
      Resource = module.posting_queue.arn
    },
    {
      Action = [
        "events:PutEvents",
      ]
      Effect   = "Allow"
      Resource = module.event_bridge.arn
    },
  ]
  event_source_arns = {
    posting_queue = module.posting_queue.arn
  }
  environment_variables = {
    EVENT_BUS_NAME = var.event_bridge_name
  }

}

module "posting_dlq" {
  source       = "./sqs"
  project_name = "Posting"
  is_dlq       = true
  name         = "DLQ.fifo"
}

module "posting_queue" {
  source                = "./sqs"
  project_name          = "Posting"
  name                  = "Queue.fifo"
  dead_letter_queue_arn = module.posting_dlq.arn
  max_receive_count     = 1
  publisher_arns        = [module.event_bridge.posting_rule_arn]
}

module "posted_dlq" {
  source       = "./sqs"
  project_name = "Posted"
  is_dlq       = true
  name         = "PostedDLQ.fifo"
}

module "posted_queue" {
  source                = "./sqs"
  project_name          = "Posted"
  name                  = "PostedQueue.fifo"
  dead_letter_queue_arn = module.posted_dlq.arn
  max_receive_count     = 1
  publisher_arns        = [module.event_bridge.posted_rule_arn]
}

module "sns" {

  source = "./sns"

}

#ForeignTransaction Lambda
module "fx_lambda" {
  source       = "./lambda_function"
  lambda_name  = "fxchecker"
  project_name = "payments"
  timeout      = 120
  memory_size  = 2048
  policies     = []
  
}

module "sfn" {
  source = "./stepfunction"

  name = join("-", ["transaction-validation-workflow", random_string.this.id])

  type = "standard"

  definition = local.definition_template
  publish    = true

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }

  service_integrations = {

    xray = {
      xray = true
    }

    stepfunction = {
      stepfunction = true
    }

    eventbridge = {
      eventbridge = true
    }
    
    sns = {
      sns = true
    }


  }

  attach_policy_jsons = true
  policy_jsons = [<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:*"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
  ]
  number_of_policy_jsons = 1

  attach_policy = true
  policy        = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

  attach_policies    = true
  policies           = ["arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess"]
  number_of_policies = 1



  ###########################
  # END: Additional policies
  ###########################

  sfn_state_machine_timeouts = {
    create = "30m"
    delete = "50m"
    update = "30m"
  }

  tags = {
    Module = "step_function"
  }
}

resource "random_string" "this" {
  length = 4
  special = false
}

#--------------------------------------------------------------
# Adding guidance solution ID via AWS CloudFormation resource
#--------------------------------------------------------------
resource "aws_cloudformation_stack" "guidance_deployment_metrics" {
    name = "tracking-stack"
    template_body = <<STACK
    {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "AWS Guidance ID (SO123456)",
        "Resources": {
            "EmptyResource": {
                "Type": "AWS::CloudFormation::WaitConditionHandle"
            }
        }
    }
    STACK
}
