resource "aws_sns_topic" "payment_posting_failure" {
  name = "PaymentPostingFailure"
  kms_master_key_id = aws_kms_alias.a.name
}

resource "aws_kms_key" "this" {
  description             = "KMS key 1"
  deletion_window_in_days = 10
  key_usage               = "ENCRYPT_DECRYPT"
}

resource "aws_kms_alias" "a" {
  name          = "alias/my-key-alias"
  target_key_id = aws_kms_key.this.key_id
}

