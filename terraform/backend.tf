terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_TF_STATE_BUCKET"
    key            = "REPLACE_WITH_TF_STATE_KEY"
    region         = "REPLACE_WITH_AWS_REGION"
    dynamodb_table = "REPLACE_WITH_TF_LOCK_TABLE"
    encrypt        = true
  }
}
