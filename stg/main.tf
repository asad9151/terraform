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
    bucket = "com.dnb.dot.infrastructure.stg"
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

module "rds_security_group" {
  source               = "../modules/security-group"
  create_securityGroup = true
  egress_fromPort      = 0
  egress_protocol      = -1
  egress_toPort        = 0
  ingress_cidrBlocks   = ["10.0.0.0/8", "158.151.0.0/16"]
  ingress_fromPort     = 3306
  ingress_protocol     = 6
  ingress_toPort       = 3306
  securityGroup_name   = "irsch-rds-${var.env}"
  tags                 = module.util.tags
  vpc_id               = module.util.vpc_id
}

module "mysql" {
  source                      = "../modules/mysql"
  account_id                  = module.util.account_id
  allocated_storage           = 250
  apply_immediately           = true
  availability_zone           = ""
  backup_retention_period     = 7
  backup_window               = "00:00-00:30"
  create_database             = true
  create_enable_events        = false
  dbaTempPassword             = "Password1234"
  dbaUserName                 = "irschmysqldba"
  enable_performance_insights = false
  engine                      = "mysql"
  engine_version              = "5.7.22"
  final_snapshot_identifier   = "irsch-stg-finalSnapshot"
  identifier                  = "irsch-stg"
  instance_class              = "db.m5.large"
  is_multi_az                 = false
  logs_to_export_to_cw        = "slowquery"
  max_allocated_storage       = 0
  monitoring_interval         = 0
  name                        = ""
  parameter_group_name        = "irsch-stg-param-mysql57"
  region                      = module.util.region
  replicate_source_db         = ""
  security_group              = module.rds_security_group.securityGroup_id
  skip_final_snapshot         = true
  sns_name_for_cwMonitor      = ""
  storage_type                = "gp2"
  subnet_group_name           = "stage db group"
  tags                        = module.util.tags
}
