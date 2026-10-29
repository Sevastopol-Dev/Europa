variable "epoch_id" {
  type        = number
  description = "Monotonically increasing sequence identifier representing the active Moving Target Defense (MTD) temporal epoch window."

  validation {
    condition     = var.epoch_id >= 0
    error_message = "The epoch_id variable must be a non-negative integer sequence."
  }
}

variable "quarantine_honeybucket" {
  type        = string
  description = "Unique bucket identifier or ARN designated for capturing dynamic honeytoken access logs, compromised credentials, and containment payloads."

  validation {
    condition     = length(var.quarantine_honeybucket) > 0
    error_message = "The quarantine_honeybucket variable must not be empty."
  }
}

variable "kms_deletion_window" {
  type        = number
  default     = 7
  description = "Waiting period (in days) before scheduled deletion of KMS key materials associated with expired temporal identity contracts."

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "The kms_deletion_window must be between 7 and 30 days."
  }
}

variable "ephemeral_pipeline_policy" {
  type        = any
  description = "JSON document or policy object defining short-lived JIT IAM permissions and temporal validity bounds for execution pipelines."
}