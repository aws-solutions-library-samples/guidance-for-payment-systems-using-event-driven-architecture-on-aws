variable "project_name" {
  type        = string
  description = "Project name used in a lambda function name prefix"
}

variable "lambda_name" {
  type        = string
  description = "Lambda function name - should match the folder name in the src folder"
}

variable "efs_mount" {
  type = object({
    file_system_arn  = string
    access_point_arn = string
    mount_path       = string
  })
  description = "(Optional) Amazon EFS to be accessed by the Lambda function."
  default     = null
}

variable "environment_variables" {
  type        = map(string)
  description = "(Optional) Map of environment variables that are accessible from the function code during execution"
  default     = {}
}

variable "timeout" {
  type        = number
  description = "Amount of time your Lambda Function has to run in seconds. Defaults to 3"
  default     = 3
}

variable "memory_size" {
  type        = number
  description = "Amount of memory in MB your Lambda Function can use at runtime. Defaults to 128"
  default     = 128
}

variable "policies" {
  type = list(object({
    Action   = list(string)
    Effect   = string
    Resource = any
  }))
  default = []
}

variable "event_source_arns" {
  type        = map(any)
  default     = {}
  description = "Map of SQS Events - define only if an event-source mapping needs to be created"
}

#Boolean variable needed for this instead of relying on whether var.event_source_arn empty, otherwise Terraform complians that count depends on resource attributes that cannot be determined until apply
variable "create_event_source_mapping" {
  type        = bool
  description = "Determines if an event-source mapping should be created"
  default     = true
}

variable "create_event_invoke_config" {
  type        = bool
  description = "Event invoke config to be created"
  default     = false
}

variable "destination_resource_arn" {
  type        = string
  description = "ARN of destination of Lambda function"
  default     = ""
}