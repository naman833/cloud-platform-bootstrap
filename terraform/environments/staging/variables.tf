variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type = string
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "project" {
  type    = string
  default = "cloud-platform"
}

variable "owner" {
  type    = string
  default = "platform-team"
}

variable "cost_center" {
  type    = string
  default = "engineering"
}

variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "k8s_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type    = string
  default = "cloud-platform-bootstrap"
}

variable "tf_state_bucket" {
  type = string
}

variable "tf_lock_table" {
  type = string
}
