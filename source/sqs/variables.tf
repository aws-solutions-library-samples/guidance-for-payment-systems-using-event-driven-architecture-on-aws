variable "project_name" {
  type        = string
  description = "Project name used for naming of the queue"
}

variable "is_dlq" {
  type        = bool
  description = "if set to true, no redrive is required"
  default     = false
}

variable "name" {
  type        = string
  description = "Queue name"
}

variable "max_receive_count" {
  type        = number
  description = "number of retries before mving the message to DLQ"
  default     = 2
}

variable "dead_letter_queue_arn" {
  type        = string
  description = "ARN of the DLQ to move the undelivered messages to"
  default     = null
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "The visibility timeout for the queue"
  default     = 120
}

variable "publisher_arns" {
  type        = list(string)
  description = "Optional list of ARNs allowed to publish message"
  default     = []
}