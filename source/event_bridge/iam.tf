resource "aws_iam_role" "this" {
  name_prefix        = "posting"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "put_record" {
  name_prefix = "posting"
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "states:StartExecution"
            ],
            "Resource": [
                "${var.state_machine_arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_posting" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.put_record.arn
}

resource "aws_iam_role" "auth_lambda" {
  name = "event_bridge_lambda_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "auth_lambda_policy" {
  name        = "lambda_invoke_policy"
  description = "Policy to grant Lambda invoke permission"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "lambda:InvokeFunction",
      Effect   = "Allow",
      Resource = var.enrich_lambda_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "auth_lambda_attachment" {
  policy_arn = aws_iam_policy.auth_lambda_policy.arn
  role       = aws_iam_role.auth_lambda.name
}

resource "aws_iam_role" "event_bridge_cloudwatch_role" {
  name = "event_bridge_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy" "event_bridge_cloudwatch_policy" {
  name        = "event_bridge_cloudwatch_policy"
  description = "Policy for EventBridge to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = aws_cloudwatch_log_group.cctran.arn
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "event_bridge_cloudwatch_attachment" {
  policy_arn = aws_iam_policy.event_bridge_cloudwatch_policy.arn
  role       = aws_iam_role.event_bridge_cloudwatch_role.name
}

resource "aws_iam_role" "foriegn_role" {
  name = "foriegn_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy" "foriegn_cloudwatch_policy" {
  name        = "foreign_cloudwatch_policy"
  description = "Policy for EventBridge to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = aws_cloudwatch_log_group.this.arn
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "foreign_cloudwatch_attachment" {
  policy_arn = aws_iam_policy.foriegn_cloudwatch_policy.arn
  role       = aws_iam_role.foriegn_role.name
}

resource "aws_iam_role" "event_bridge_sqs_role" {
  name = "event_bridge_sqs_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy" "event_bridge_sqs_policy" {
  name        = "event_bridge_sqs_policy"
  description = "Policy for EventBridge to send messages to SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
        ],
        Resource = var.posted_queue_arn,
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "event_bridge_sqs_attachment" {
  policy_arn = aws_iam_policy.event_bridge_sqs_policy.arn
  role       = aws_iam_role.event_bridge_sqs_role.name
}