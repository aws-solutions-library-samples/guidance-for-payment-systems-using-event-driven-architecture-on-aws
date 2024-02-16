variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "the region of deployment"
}

variable "event_rule_name" {
  type        = string
  description = "Name of the Event Rule"
  default     = "ec2-running"
}

variable "stream_arn" {
  type        = string
  default     = ""
  description = "The DYnaamoDB Stream ARN"
}

variable "event_bridge_name" {
  type        = string
  description = "Name of the Event Bus"
  default     = "payments"
}

variable "lambda_arn" {
  type        = string
  description = "ARN of the Lambda"
  default     = ""
}