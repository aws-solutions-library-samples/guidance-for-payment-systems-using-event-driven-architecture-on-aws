variable "stream_arn" {
  type        = string
  default     = ""
  description = "The DynamoDB Stream ARN"
}

variable "eb_arn" {
  type        = string
  description = "Name of the Event Bus"
  default     = ""
}

variable "lambda_arn" {
  type        = string
  description = "ARN of the Lambda"
  default     = ""
}

variable "target_event_detail_type" {
  type        = string
  description = "Detail-Type property of the event published to the target."
  default     = null
}

variable "target_event_source" {
  type        = string
  description = "Source property of the event published to the target."
  default     = null
}

variable "kms_key_id" {
  description = "Pass the ARN of the KMS Key Id for CMK"
  type        = string
  default     = null
}
