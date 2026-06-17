variable "project" {
  type = string
}

variable "github_org" {
  type        = string
  description = "GitHub organisation or user (e.g. naman833)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "tf_state_bucket" {
  type = string
}

variable "tf_lock_table" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
