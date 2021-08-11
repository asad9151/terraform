module "util" {
  source = "../utilities"
  env    = var.env
}

provider "aws" {
  region  = module.util.region
  version = "~> 3.0"
}

terraform {
  backend "s3" {
    bucket = "com.dnb.dot.infrastructure.prd"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "remote_state_s3" {
  backend = "s3"

  config = {
    region = module.util.region
    bucket = module.util.backend_s3_bucketName
    key    = "${module.util.project}/${var.env}/terraform.tfstate"
  }
}

module "prod" {
  source                = "../global"
  account_id            = module.util.account_id
  conditional-resources = module.util.conditional-resources
  env                   = var.env
  lambda_concurrency    = module.util.lambda_concurrency
  lambda_properties     = module.util.lambda_properties
  lambda_subnets        = module.util.lambda_subnets
  tags                  = module.util.tags
  vpc_id                = module.util.vpc_id
}
