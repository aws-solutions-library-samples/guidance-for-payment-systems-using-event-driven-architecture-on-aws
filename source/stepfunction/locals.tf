locals {


  aws_service_policies = {

    xray = {
      xray = {
        actions = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        default_resources = ["*"]
      }
    }

    stepfunction = {
      stepfunction = {
        actions = [
          "states:StartExecution"
        ]
        default_resources = ["arn:aws:events:${local.aws_region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"]
      }
    }

    # https://docs.aws.amazon.com/step-functions/latest/dg/eventbridge-iam.html
    eventbridge = {
      eventbridge = {
        actions = [
          "events:PutEvents"
        ]
        default_resources = ["*"]
      }
    }
    
    sns = {
      sns = {
        actions = [
          "sns:Publish"
        ]
        default_resources = ["*"]
      }
    }

    # https://docs.aws.amazon.com/step-functions/latest/dg/activities-iam.html
    no_tasks = {
      deny_all = {
        effect            = "Deny"
        actions           = ["*"]
        default_resources = ["*"]
      }
    }

  }
}

data "aws_caller_identity" "current" {}