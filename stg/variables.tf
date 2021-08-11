variable "env" {
  description = "Variable to specify environment shortname to pick the right environment files"
}

variable "create_enable_events" {
  description = "This variable acts as a flag and will help us enable disable events invocations in an environment"
  default     = true
}

//For rest of the information related to configurations like tags, lambda properties, subnets, vpc id's, account id's
// - please refer to the utilities package main.tf

