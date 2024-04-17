locals {
  src_dir            = abspath("${path.root}/src/${var.lambda_name}/")
  build_dir          = abspath("${path.root}/build/${var.lambda_name}/")
  function_name      = "${var.project_name}-${var.lambda_name}"
  log_retention_days = 14
  managed_policies = [
    data.aws_iam_policy.aws_xray_write_only_access.arn,
    data.aws_iam_policy.aws_dynamodb_full_access.arn
  ]
  environment_variables = merge(
    {
      POWERTOOLS_SERVICE_NAME = var.lambda_name
    },
    var.environment_variables
  )
}

#To Perform Clean up after rerun
resource "null_resource" "dependencies" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${local.build_dir};
      mkdir -p ${local.build_dir}/python;
      cp -a ${local.src_dir}/. ${local.build_dir}/python;
      #cp -a ${local.src_dir}/. ${local.build_dir}/python;
    EOT
  }

  provisioner "local-exec" {
    command = "pip3 install -r ${local.build_dir}/python/requirements.txt -t ${local.build_dir}/python --upgrade --no-cache-dir"
  }
}

data "archive_file" "this" {
  type = "zip"

  source_dir  = "${local.build_dir}/python/"
  output_path = "${local.build_dir}/python/${var.lambda_name}.zip"

  excludes = [
    "__pycache__"
  ]

  depends_on = [
    null_resource.dependencies
  ]
}

data "aws_iam_policy" "aws_xray_write_only_access" {
  name = "AWSXrayWriteOnlyAccess"
}

data "aws_iam_policy" "aws_dynamodb_full_access" {
  name = "AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  role             = aws_iam_role.this.arn
  filename         = data.archive_file.this.output_path
  timeout          = var.timeout
  source_code_hash = data.archive_file.this.output_base64sha256
  memory_size      = var.memory_size
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = local.environment_variables
  }


}

resource "aws_iam_role" "this" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = local.managed_policies

  inline_policy {
    name = "${local.function_name}-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = flatten(
        [
          # {
          #   Action = [
          #     "ec2:CreateNetworkInterface",
          #     "ec2:DeleteNetworkInterface",
          #     "ec2:DescribeInstances",
          #     "ec2:DescribeNetworkInterfaces"
          #   ]
          #   Effect   = "Allow"
          #   Resource = "*"
          # },
          {
            Action = [
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Effect = "Allow"
            Resource = [
              "${aws_cloudwatch_log_group.this.arn}:*"
            ]
          },

          var.policies,
        ]
      )
    })
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/lambda/${local.function_name}"

  retention_in_days = local.log_retention_days
}

resource "aws_lambda_event_source_mapping" "sqs_scan" {
  for_each         = var.event_source_arns
  event_source_arn = each.value
  enabled          = true
  function_name    = aws_lambda_function.this.arn
  batch_size       = 1
}