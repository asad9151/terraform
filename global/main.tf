/*Following locals is to help decide on the roles that needs to be set
at the KMS policy for the KMS Key being created for SQS queue - DirectPlusUsage
Also, included roles for SQS policy used on SendToUnity queue*/
locals {
  accounts = {
    "576929353350" = ["dnb-irs-dev_PowerUser_Role", "dnb-irs-dev_SysAdmin_Role", "dnb-irs-dev_CloudAdmin_Role"]
    "292120075268" = ["Enterprise_CloudAdmin_Role", "Enterprise_SysAdmin_Role"]
    # This configuration is for Unity team access on SQS KMS and SQS
    "259300059461" = ["iresearch${var.env == "q2" || var.env == "q2a" ? "Stg" : "Prod"}"]
    "008635507388" = ["OpalInstance", "iresearchSQS"]
    # This configuration is for both ascent exclusions and violations access on SQS KMS and SQS
    # except the interpolation of a prefix 'violations' happen at the resource
    "674031437623" = "iresearch-res-lambda-iam_role-dev"
    "484330945175" = "iresearch-res-lambda-iam_role-qa"
    "747052504686" = "iresearch-res-lambda-iam_role-uat"
    "431314012798" = "iresearch-res-lambda-iam_role-stg"
    "352946570319" = "iresearch-res-lambda-iam_role-prd"
  }
  isAutomationEnvironment = substr(var.env, 2, 1) == "a" ? true : false
  dns_zone                = var.route53_dns_zone[var.account_id]
  isAPrivateZone          = local.dns_zone == "irs.dnb.net" ? true : false
}

/****************************************************
Security Group for Lambda functions
*****************************************************/
module "lambda_security_group" {
  source               = "../modules/security-group"
  create_securityGroup = true
  egress_fromPort      = 0
  egress_protocol      = -1
  egress_toPort        = 0
  ingress_fromPort     = 0
  ingress_protocol     = -1
  ingress_toPort       = 0
  securityGroup_name   = substr(var.env, 0, 1) == "d" && var.env != "dr" ? "irsch-${var.env}-lambda" : "irsch-lambda-${var.env}"
  tags                 = var.tags
  vpc_id               = var.vpc_id
}

/****************************************************
KMS Key used for encrypting sensitive information
*****************************************************/
module "kms" {
  source      = "../modules/kms"
  description = "Columbo iResearch Application Key for - ${var.env}"
  name        = "irsch_${var.env}_key"
  policy      = ""
  tags        = var.tags
}

/***************************************************
KMS key for SQS queues encryption of data
*****************************************************/
module "sqs_kms" {
  source      = "../modules/kms"
  description = "Columbo iResearch SQS Key for - ${var.env}"
  name        = "irsch_${var.env}_sqs_key"
  policy      = templatefile("${path.module}/templates/sqs_kms_policy.json", { account_id = var.account_id, adminPrincipals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", var.account_id, local.accounts[var.account_id]))
    unityPrincipals            = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr", "q2"), var.env) ? "259300059461" : "008635507388", local.accounts[contains(list("pd", "dr", "q2"), var.env) ? "259300059461" : "008635507388"])),
    ascentExclusionsPrincipals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623", local.accounts[contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623"])),
    ascentViolationsPrincipals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623", join("-",list("violations",local.accounts[contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623"]))))
  })
  tags = var.tags
}

/************************************************************
Elastic Search Domain and the necessary resources
*************************************************************/
module "es_kibana_cognito_pool" {
  source              = "../modules/cognito-pool"
  create_cognito_pool = false
  env                 = var.env
  tags                = var.tags
}

module "es_security_group" {
  source               = "../modules/security-group"
  create_securityGroup = var.conditional-resources["create_es_domain"]
  egress_fromPort      = 0
  egress_protocol      = -1
  egress_toPort        = 0
  ingress_cidrBlocks   = ["10.0.0.0/8", "158.151.0.0/16"]
  ingress_fromPort     = 443
  ingress_protocol     = 6
  ingress_toPort       = 443
  securityGroup_name   = "irsch-elasticsearch-${var.env}"
  tags                 = var.tags
  vpc_id               = var.vpc_id
}

module "es_domain" {
  source                      = "../modules/elasticsearch"
  account_id                  = var.account_id
  cognito_access_iam_role_arn = ""
  cognito_identity_pool_id    = module.es_kibana_cognito_pool.cognito_identity_pool_id
  cognito_user_pool_id        = module.es_kibana_cognito_pool.cognito_user_pool_id
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_esDomain             = var.conditional-resources["create_es_domain"]
  domain_name                 = "irsch-${var.env}-logsdomain"
  domain_version              = "6.5"
  ebs_enabled                 = true
  enable_authentication       = false
  encrypt_at_rest             = true
  instance_count              = var.env == "pd" ? 2 : 1
  instance_type               = "m5.large.elasticsearch"
  iops                        = 0
  security_group_ids          = module.es_security_group.securityGroup_id
  sns_arn_for_cwMonitor       = module.invokeProcessCWAlarmEventsLambda_sns.arn
  subnet_ids                  = list(var.lambda_subnets[0])
  tags                        = var.tags
  volume_size                 = var.env == "pd" ? 500 : 100
  volume_type                 = "gp2"
  //cognito_access_iam_role_arn   = "arn:aws:iam::${var.account_id}:role/service-role/CognitoAccessForAmazonES"
}
data "archive_file" "ProcessCWLogsToES" {
  output_path = "../tmp/ProcessCWLogsToES.zip"
  source_dir  = "../lib/ProcessCWLogsToES"
  type        = "zip"
}
module "esProcess_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency != -1 ? var.lambda_concurrency * 2 : var.lambda_concurrency
  create_enable_events        = false
  create_lambda               = var.conditional-resources["create_log_subscription"]
  create_log_subscription     = false
  description                 = "Logs from lambda log groups are consumed and sent over to ES."
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = null
  func_handler                = "index.handler"
  func_name                   = "irsch_${var.env}_ProcessCWLogsToES"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = data.archive_file.ProcessCWLogsToES.output_path
  runtime                     = var.lambda_properties["nodejs10LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
  tracing_config              = "PassThrough"

  variables = {
    "ES_ENDPOINT" = module.es_domain.endpoint
  }
}

module "cloudwatch-subscription-permission" {
  source                             = "../modules/cloudwatch-subscription-permission"
  create_log_subscription_permission = var.conditional-resources["create_log_subscription"]
  destination_func_arn               = module.esProcess_lambda.arn
}
data "archive_file" "ElasticSearchMaintenance" {
  output_path = "../tmp/ElasticSearchMaintenance.zip"
  source_dir  = "../lib/ElasticSearchMaintenance"
  type        = "zip"
}
module "esMaintenance_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = false
  create_lambda               = var.conditional-resources["create_es_domain"]
  create_log_subscription     = false
  description                 = "Used for general elastic search maintanence such as removing old indexes and compaction."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "ElasticSearchCurator.lambda_handler"
  func_name                   = "irsch_${var.env}_ElasticSearchMaintenance"
  memory                      = var.lambda_properties["128MBLambdaMemory"]
  payload_filename            = data.archive_file.ElasticSearchMaintenance.output_path
  funcName_that_consume_CWLog = null
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
  tracing_config              = "PassThrough"

  variables = {
    "ES_ENDPOINT" = module.es_domain.endpoint
    "FromAddress" = var.env == "pd" ? "iResearchProdESMaintenance@dnb.com" : "iResearchESMaintenance@dnb.com"
    "ToAddress"   = var.env == "pd" ? "iResearchDevSupport@DNB.com" : "iResearchNonProdSupport@DNB.com"
    "Days"        = var.env == "pd" ? "60" : "37"
  }
}

module "esMaintenance_CloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_invokeElasticSearchMaintenanceLambda"
  create_enable_cloudwatch_event = var.conditional-resources["create_es_domain"]
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.esMaintenance_lambda.arn
  expression                     = "rate(1 day)"
  isLambdaFunction               = var.conditional-resources["create_es_domain"]
  lambda_function_name           = module.esMaintenance_lambda.funcName
  tags                           = var.tags
}

module "elasticSearch_route53" {
  source                       = "../modules/route53"
  create_route53_record        = var.conditional-resources["create_es_domain"]
  destination_endpoint_address = module.es_domain.endpoint
  dns_zone                     = local.dns_zone
  name                         = "irsch-es-${var.env == "q1" ? "qa" : var.env == "q2" ? "stg" : var.env}.${local.dns_zone == null ? "" : local.dns_zone}"
  isAPrivateZone               = local.isAPrivateZone
}

/****************************************************
IAM Role for Lambda functions and all resource of IAM
*****************************************************/
module "lambda_role" {
  source                        = "../modules/iam"
  account_id                    = var.account_id
  conditional-resources         = var.conditional-resources
  cs_api_gw_arn                 = module.gateway-cs.arn
  cs_api_gw_stage_name          = module.gateway-cs.stage
  elasticsearch_name            = module.es_domain.name
  es_caseExtract_name           = module.esCaseExtract_domain.name
  env                           = var.env
  kms_arn                       = module.kms.arn
  region                        = var.region
  sftp_server_id                = module.sftp_server.id
  sqs_kms_arn                   = module.sqs_kms.arn
  cs_api_gw_id                  = module.gateway-cs.id
  ui_api_gw_id                  = module.apiGateway.id
  tags                          = var.tags
}

/****************************************************
SFTP && API Lambda layer definitions
*****************************************************/
module "sftpLibraries_lambda_layer" {
  source              = "../modules/lambda-layers"
  compatible_runtimes = ["python3.6", "python3.7"]
  filename            = "../lib/sftp-layer.zip"
  layer_name          = "irsch_${var.env}_SFTPLibraries"
}

module "apiLibraries_lambda_layer" {
  source              = "../modules/lambda-layers"
  compatible_runtimes = ["python3.6", "python3.7"]
  filename            = "../lib/api-layer.zip"
  layer_name          = "irsch_${var.env}_ApiLibraries"
}

module "sftpLibraries_py37_lambda_layer" {
  source              = "../modules/lambda-layers"
  compatible_runtimes = ["python3.7"]
  filename            = "../lib/sftp-layer_py37.zip"
  layer_name          = "irsch_${var.env}_SFTPLibraries_PY37"
}

module "snowflakeLibraries_lambda_layer" {
  source              = "../modules/lambda-layers"
  compatible_runtimes = ["python3.7"]
  filename            = "../lib/SnowflakeLibraries.zip"
  layer_name          = "irsch_${var.env}_SnowflakeLibraries"
}
/****************************************************
MYSQL RDS Parameter group, subnet group, security group and DB
*****************************************************/
module "db_param_group" {
  source                = "../modules/dbParameterGroup"
  create_db_param_group = var.conditional-resources["create_database"]
  env                   = var.env == "q1" ? "qa" : var.env == "dev2" ? "dev" : var.env
  family                = contains(list("dev2", "q1"), var.env) ? "mysql8.0" : "mysql5.7"
  tags                  = var.tags
}

module "db_subnet_group" {
  source                 = "../modules/subnet-group"
  create_db_subnet_group = var.conditional-resources["create_db_subnet_group"] && var.conditional-resources["create_database"]
  name                   = var.env == "dev2" ? "irsch-dev-db-group" : "irsch-${var.env}-db-group"
  subnet_ids             = var.mysql-subnetIds
  tags                   = var.tags
}

module "rds_security_group" {
  source               = "../modules/security-group"
  create_securityGroup = var.conditional-resources["create_database"]
  egress_fromPort      = 0
  egress_protocol      = -1
  egress_toPort        = 0
  ingress_cidrBlocks   = ["10.0.0.0/8", "158.151.0.0/16"]
  ingress_fromPort     = 3306
  ingress_protocol     = 6
  ingress_toPort       = 3306
  securityGroup_name   = var.env == "dev2" ? "irsch-dev-rds" : "irsch-rds-${var.env}"
  tags                 = var.tags
  vpc_id               = var.vpc_id
}

module "mysql" {
  source                      = "../modules/mysql"
  account_id                  = var.account_id
  allocated_storage           = var.env == "dev2" ? 50 : 700
  allow_major_version_upgrade = var.env == "dev2" ? true : false
  apply_immediately           = true
  availability_zone           = ""
  backup_retention_period     = var.env == "pd" ? 14 : var.env == "q1" ? 7 : 1
  backup_window               = var.env == "dr" ? "" : "00:00-00:30"
  create_database             = var.conditional-resources["create_database"]
  create_enable_events        = var.conditional-resources["create_enable_events"]
  dbaTempPassword             = var.env == "dr" ? "" : "Password1234"
  dbaUserName                 = var.env == "dev2" ? "iresearch" : var.env == "dr" ? "" : "irschmysqldba"
  enable_performance_insights = contains(list("pd", "q1"), var.env) ? "true" : "false"
  engine                      = var.env == "dr" ? "" : "mysql"
  engine_version              = contains(list("dev2", "q1"), var.env) ? "8.0.23" : var.env == "dr" ? "" : "5.7.33"
  final_snapshot_identifier   = "irsch-${var.env == "q1" ? "qa" : var.env == "dev2" ? "dev" : var.env}-finalSnapshot"
  identifier                  = var.env == "q1" ? "irsch-qa" : var.env == "pd" ? "irsch-pd" : var.env == "dr" ? "irsch-pd-replica" : "irsch-dev"
  instance_class              = var.env == "pd" ? "db.m4.2xlarge" : var.env == "dr" ? "db.t2.large" : var.env == "dev2" ? "db.t3.large" : "db.m5.xlarge"
  is_multi_az                 = var.env == "pd" ? true : false
  logs_to_export_to_cw        = var.env == "q1" ? "error,general,slowquery" : "error,slowquery"
  max_allocated_storage       = var.env == "pd" ? 1000 : var.env == "dev2" ? 100 : 0                   //for storage autoscaling
  monitoring_interval         = contains(list("q1", "pd"), var.env) ? 60 : 0 //for enhanced monitoring
  name                        = ""
  parameter_group_name        = module.db_param_group.name
  region                      = var.region
  replicate_source_db         = var.env == "dr" ? "arn:aws:rds:us-east-1:292120075268:db:irsch-pd" : ""
  security_group              = module.rds_security_group.securityGroup_id
  skip_final_snapshot         = false
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  storage_type                = var.env == "dr" ? "" : "gp2"
  subnet_group_name           = var.conditional-resources["create_db_subnet_group"] ? module.db_subnet_group.subnet_group_name : var.env == "pd" ? "prod db group" : var.env == "q1" ? "qa subnet group" : ""
  tags                        = var.tags
}

module "rds_route53" {
  source                       = "../modules/route53"
  create_route53_record        = var.conditional-resources["create_database"]
  destination_endpoint_address = module.mysql.address
  dns_zone                     = local.dns_zone
  name                         = "irsch-rds-${var.env == "q1" ? "qa" : var.env == "dev2" ? "dev" : var.env}.${local.dns_zone == null ? "" : local.dns_zone}"
  isAPrivateZone               = local.isAPrivateZone
}

/****************************************************
Start - Web Gateway Resources and API GW Implementation
*****************************************************/
module "apiGateway_authorizer_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency != -1 ? 25 : var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Gateway authorizer."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "irschAPIGWAuthorizer.lambda_handler"
  func_name                   = "irsch_${var.env}_ApigwAuthorizer"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "logonValidation_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Validates incoming user logon request."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "irschGUIAuthenticationLambda.lambdaHandler"
  func_name                   = "irsch_${var.env}_LogonValidation"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "submitCase_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Creates a new research request and case."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.SubmitCaseHandler"
  func_name                   = "irsch_${var.env}_SubmitCase"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveCase_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.env == "dr" || substr(var.env, 0, 1) != "d" ? var.lambda_concurrency * 2 : var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Retrieve a single case for a researcher."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.RetrieveCaseHandler"
  func_name                   = "irsch_${var.env}_RetrieveCase"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "recordLogin_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Creates user session and updates user table."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.RecordLoginHandler"
  func_name                   = "irsch_${var.env}_RecordLogin"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "takecaseaction_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Takes action on a case (e.g. close/reroute/reassign)."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.TakeCaseActionHandler"
  func_name                   = "irsch_${var.env}_TakeCaseAction"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "updateResearchResults_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Updates a case's research results."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.UpdateResearchResultsHandler"
  func_name                   = "irsch_${var.env}_UpdateResearchResults"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "requestAttachmentLink_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.attachment.requestAttachmentLinklambda.handler"
  func_name                   = "irsch_${var.env}_RequestAttachmentLink"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveInitialData_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates S3 temporary URL for user upload."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.retrieveInitialData.svclambda.handler"
  func_name                   = "irsch_${var.env}_RetrieveInitialData"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveAdminData_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Queries data for use by Admin screens."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.retrieveadmindata.svclambda.handler"
  func_name                   = "irsch_${var.env}_RetrieveAdminData"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "updateAdminData_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Updates data for use by Admin screens."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateadmindata.svclambda.handler"
  func_name                   = "irsch_${var.env}_UpdateAdminData"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "deleteAttachment_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Marks an attachment for deletion."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.attachment.deleteAttachmentlambda.handler"
  func_name                   = "irsch_${var.env}_DeleteAttachment"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "updateUserData_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Updates a user's preferences."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateuserdata.svclambda.handler"
  func_name                   = "irsch_${var.env}_UpdateUserData"
  layers                      = [module.apiLibraries_lambda_layer.arn,""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveCaseSummary_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.env == "dr" || substr(var.env, 0, 1) != "d" ? var.lambda_concurrency * 2 : var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Queries summary case-level data for a researcher or local admin."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.RetrieveCaseSummaryHandler"
  func_name                   = "irsch_${var.env}_RetrieveCaseSummary"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "firmographicsData_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Invokes D+ firmographics and stores results in cache."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.FirmographicsDataHandler"
  func_name                   = "irsch_${var.env}_FirmographicsData"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveRequestSummary_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Queries summary request-level data for a submitter."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.RetrieveRequestSummaryHandler"
  func_name                   = "irsch_${var.env}_RetrieveRequestSummary"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "mocProxy_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Proxy to Match on Cloud lookup service."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.proxy.proxyLambda.handler"
  func_name                   = "irsch_${var.env}_MocProxy"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["256MBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "takeRequestAction_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Takes action on a request (e.g. add/delete research types)."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.TakeRequestActionHandler"
  func_name                   = "irsch_${var.env}_TakeRequestAction"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "smartyStreetUsStreetProxy_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Proxies street address requests to Smarty Streets."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.proxy.smartyStreetProxyLambda.handler"
  func_name                   = "irsch_${var.env}_SmartyStreetUsStreetProxy"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["256MBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "smartyStreetUsAutocompleteProxy_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Proxies requests to Smarty Streets while user is typing."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.proxy.smartyStreetProxyLambda.handler"
  func_name                   = "irsch_${var.env}_SmartyStreetUsAutocompleteProxy"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["256MBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "getNext_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Pagination."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.GetNextHandler"
  func_name                   = "irsch_${var.env}_GetNext"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "updateGetNext_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Pagination."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.UpdateGetNextHandler"
  func_name                   = "irsch_${var.env}_UpdateGetNext"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "trainingMediaService_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Training media on how to use iResearch."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.trainingmediaservice.trainingMediaServiceLambda.handler"
  func_name                   = "irsch_${var.env}_TrainingMediaService"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "keepaliveService_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.env == "dr" || substr(var.env, 0, 1) != "d" ? var.lambda_concurrency * 2 : var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Keep alive service."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.keepaliveservice.keepaliveServiceLambda.handler"
  func_name                   = "irsch_${var.env}_KeepaliveService"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "qualityReview_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Quality Review."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.QualityReviewHandler"
  func_name                   = "irsch_${var.env}_QualityReview"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "apiGateway" {
  source       = "../modules/gateway-ui"
  region       = var.region
  gateway_name = "irsch_${var.env}_gw"
  stage_name   = "service"
  tags         = var.tags

  authorizer_lambda_arn                           = module.apiGateway_authorizer_lambda.arn
  authorizer_lambda_funcName                      = module.apiGateway_authorizer_lambda.funcName
  autoAssign_lambda_arn                           = module.autoAssign_lambda.arn
  autoAssign_lambda_funcName                      = module.autoAssign_lambda.funcName
  deleteAttachment_lambda_arn                     = module.deleteAttachment_lambda.arn
  deleteAttachment_lambda_funcName                = module.deleteAttachment_lambda.funcName
  firmographicsData_lambda_arn                    = module.firmographicsData_lambda.arn
  firmographicsData_lambda_funcName               = module.firmographicsData_lambda.funcName
  getNext_lambda_arn                              = module.getNext_lambda.arn
  getNext_lambda_funcName                         = module.getNext_lambda.funcName
  keepaliveService_lambda_arn                     = module.keepaliveService_lambda.arn
  keepaliveService_lambda_funcName                = module.keepaliveService_lambda.funcName
  logonValidation_lambda_arn                      = module.logonValidation_lambda.arn
  logonValidation_lambda_funcName                 = module.logonValidation_lambda.funcName
  mocProxy_lambda_arn                             = module.mocProxy_lambda.arn
  mocProxy_lambda_funcName                        = module.mocProxy_lambda.funcName
  requestAttachmentLink_lambda_arn                = module.requestAttachmentLink_lambda.arn
  requestAttachmentLink_lambda_funcName           = module.requestAttachmentLink_lambda.funcName
  retrieveRequestSummary_lambda_arn               = module.retrieveRequestSummary_lambda.arn
  retrieveRequestSummary_lambda_funcName          = module.retrieveRequestSummary_lambda.funcName
  retrieveAdminData_lambda_arn                    = module.retrieveAdminData_lambda.arn
  retrieveAdminData_lambda_funcName               = module.retrieveAdminData_lambda.funcName
  retrieveCase_lambda_arn                         = module.retrieveCase_lambda.arn
  retrieveCase_lambda_funcName                    = module.retrieveCase_lambda.funcName
  retrieveCaseSummary_lambda_arn                  = module.retrieveCaseSummary_lambda.arn
  retrieveCaseSummary_lambda_funcName             = module.retrieveCaseSummary_lambda.funcName
  retrieveInitialData_lambda_arn                  = module.retrieveInitialData_lambda.arn
  retrieveInitialData_lambda_funcName             = module.retrieveInitialData_lambda.funcName
  smartyStreetUsAutocompleteProxy_lambda_arn      = module.smartyStreetUsAutocompleteProxy_lambda.arn
  smartyStreetUsAutocompleteProxy_lambda_funcName = module.smartyStreetUsAutocompleteProxy_lambda.funcName
  smartyStreetUsStreetProxy_lambda_arn            = module.smartyStreetUsStreetProxy_lambda.arn
  smartyStreetUsStreetProxy_lambda_funcName       = module.smartyStreetUsStreetProxy_lambda.funcName
  submitCase_lambda_arn                           = module.submitCase_lambda.arn
  submitCase_lambda_funcName                      = module.submitCase_lambda.funcName
  takeRequestAction_lambda_arn                    = module.takeRequestAction_lambda.arn
  takeRequestAction_lambda_funcName               = module.takeRequestAction_lambda.funcName
  takeCaseAction_lambda_arn                       = module.takecaseaction_lambda.arn
  takeCaseAction_lambda_funcName                  = module.takecaseaction_lambda.funcName
  trainingMediaService_lambda_arn                 = module.trainingMediaService_lambda.arn
  trainingMediaService_lambda_funcName            = module.trainingMediaService_lambda.funcName
  updateGetNext_lambda_arn                        = module.updateGetNext_lambda.arn
  updateGetNext_lambda_funcName                   = module.updateGetNext_lambda.funcName
  updateAdminData_lambda_arn                      = module.updateAdminData_lambda.arn
  updateAdminData_lambda_funcName                 = module.updateAdminData_lambda.funcName
  updateResearchResults_lambda_arn                = module.updateResearchResults_lambda.arn
  updateResearchResults_lambda_funcName           = module.updateResearchResults_lambda.funcName
  updateUserData_lambda_arn                       = module.updateUserData_lambda.arn
  updateUserData_lambda_funcName                  = module.updateUserData_lambda.funcName
  qualityReview_lambda_arn                        = module.qualityReview_lambda.arn
  qualityReview_lambda_funcName                   = module.qualityReview_lambda.funcName
}
module "web-gateway_log_subscription"{
  source                    = "../modules/cloudwatch-subscription"
  create_log_subscription   = var.conditional-resources["create_log_subscription"]
  destination_func_arn      = module.esProcess_lambda.arn
  log_group_name            = "API-Gateway-Execution-Logs_${module.apiGateway.id}/${module.apiGateway.stage}"
  subscriptionFilter_prefix = "WebApiGW"
}
/**************************************************
End - Web Gateway Resources and API GW Implementation
***************************************************/
/****************************************************
Start - S3 Buckets definition and event notification configurations
*****************************************************/
//S3 Bucket to serve Web Content
module "uiContent_s3" {
  source         = "../modules/s3"
  acl            = "public-read"
  isVersioned    = false
  policy         = templatefile("${path.module}/templates/uiContent_bucket_policy.json", { bucket_name = "irsch-${var.env}-uicontent" })
  s3_bucket_name = "irsch-${var.env}-uicontent"
  tags           = merge(var.tags,{"PubliclyAccessible"="yes","Contents" = "Static Web Pages"})

  website = [
    {
      index_document = "index.html"
      error_document = "error.html"
    },
  ]
}

//S3 Bucket that is used to store application artifacts
module "application_s3" {
  source         = "../modules/s3"
  isVersioned    = false
  s3_bucket_name = "irsch-${var.env}-application"
  tags           = var.tags
}

//S3 Bucket that stores attachments, BDRS Responses
module "datastores_s3" {
  source          = "../modules/s3"
  cors_rules      = var.datastores_s3bucket_cors_rule
  isVersioned     = true
  lifecycle_rules = var.datastores_s3bucket_lifecycle_rules
  policy          = templatefile("${path.module}/templates/datastores_bucket_policy.json", { env = var.env, principals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr", "q2","q2a"), var.env) ? "259300059461" : "008635507388", local.accounts[contains(list("pd", "dr", "q2","q2a"), var.env) ? "259300059461" : "008635507388"])) })
  s3_bucket_name  = "irsch-${var.env}-datastores"
  tags            = var.tags
}

//S3 Bucket that stores reference data content
module "refdata_s3" {
  source          = "../modules/s3"
  isVersioned     = true
  lifecycle_rules = var.refdata_s3bucket_lifecycle_rules
  s3_bucket_name  = "irsch-${var.env}-refdata"
  tags            = var.tags
}

//S3 Bucket for BDRS response landing
module "bdrs_s3" {
  source         = "../modules/s3"
  isVersioned    = false
  s3_bucket_name = "irsch-${var.env}-irschbdrs"
  tags           = var.tags
}

//S3 Bucket Event Notification Configurations
module "s3_to_LambdaNotifications" {
  source               = "../modules/s3-events"
  create_enable_events = var.conditional-resources["create_enable_events"]

  adminReportingLambda_arn                   = module.adminReporting_lambda.arn
  cfpSftpOutboundDeliveryLambda_arn          = module.cfpSftpOutboundDelivery_lambda.arn
  datastore_s3Bucket_name                    = module.datastores_s3.name
  fileBasedAdminRequestLambda_arn            = module.fileBasedAdminRequest_lambda.arn
  generateAndorraFileLambda_arn              = module.generateAndorraFile_lambda.arn
  generateChinaFileLambda_arn                = module.generateChinaFile_lambda.arn
  generateSpainFileLambda_arn                = module.generateSpainFile_lambda.arn
  miniInvestigationUsageProcessingLambda_arn = module.miniInvestigationUsageProcessing_lambda.arn
  processUploadedAttachmentLambda_arn        = module.processUploadedAttachment_lambda.arn
  processVirusScannedAttachmentLambda_arn    = module.processVirusScannedAttachment_lambda.arn
  refDataLoaderLambda_arn                    = module.refdata_lambda.arn
  refData_s3Bucket_name                      = module.refdata_s3.name
  sftpInboundDeliveryLambda_arn              = module.sftpInboundDelivery_lambda.arn
  sftpOutboundDeliveryLambda_arn             = module.sftpOutboundDelivery_lambda.arn
  stpOutboundDeliveryLambda_arn              = module.stpOutboundDelivery_lambda.arn
  snowflake_load_s3Bucket_name               = module.snowflake_load_s3.name
  snowflake_sqs_arn                          = lookup(var.snowflake_sqs,var.env,"")
  dffRequests_s3Bucket_name                  = module.dff_requests_s3.name
  dffSubmitCaseBatchParserLambda_arn         = module.dffSubmitCaseBatchParser_lambda.arn
}

//New UI Test Environment for cache validation
module "testuiContent_s3" {
  source           = "../modules/s3"
  acl              = "public-read"
  create_s3_bucket = var.env == "q1" ? true : false
  isVersioned      = false
  policy           = templatefile("${path.module}/templates/uiContent_bucket_policy.json", { bucket_name = "irsch-${var.env}-testuicontent" })
  s3_bucket_name   = "irsch-${var.env}-testuicontent"
  tags             = merge(var.tags,{"PubliclyAccessible"="Yes","Contents" = "Static Web Pages"})

  website = [
    {
      index_document = "index.html"
      error_document = "error.html"
    }
  ]
}


/****************************************************
End - S3 Buckets Used in the application and event notification configuration
*****************************************************/
/****************************************************
Cloudfront configured on the S3 bucket with web content
*****************************************************/
module "cloudfront" {
  source              = "../modules/cloudfront"
  aliases             = list(lookup(var.cloudFront_aliases, var.env, ""))
  certificate_arn     = lookup(var.cloudFront_api_cert_arn, var.env, "")
  create_cloudFront   = lookup(var.cloudFront_aliases, var.env, "") == "" ? false : true
  default_root_object = "index.html"
  price_class         = var.env == "pd" ? "PriceClass_All" : "PriceClass_100"
  s3_bucket           = "irsch-${var.env}-uicontent"
  tags                = var.tags
}
module "cloudfront_testui" {
  source              = "../modules/cloudfront"
  aliases             = list(lookup(var.cloudFront_aliases, "${var.env}uitest", ""))
  certificate_arn     = lookup(var.cloudFront_api_cert_arn, "${var.env}uitest", "")
  create_cloudFront   = lookup(var.cloudFront_aliases, "${var.env}uitest", "") == "" ? false : true
  default_root_object = "index.html"
  s3_bucket           = "irsch-${var.env}-testuicontent"
  tags                = var.tags
}


/******************************************************
Lambda, SQS, CW Resources for BDRS processes
*******************************************************/
module "bdrsResponse_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Processes responses from BDRS."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.BDRSResponseHandler"
  func_name                   = "irsch_${var.env}_BDRSResponse"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "receiveFromBDRS_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.bdrsResponse_lambda.arn
  lambda_function_name       = module.bdrsResponse_lambda.funcName
  name                       = "irsch_${var.env}_receiveFromBDRS"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.receiveFromBDRS_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.bdrsResponse_lambda.timeout * 6
}

module "receiveFromBDRS_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_receiveFromBDRS"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "scheduleBDRSCheck_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Checks for any unanswered BDRS requests and transitions to ready to be assigned."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.SchedBDRSCheckHandler"
  func_name                   = "irsch_${var.env}_SchedBDRSCheck"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["1MinLambdaTimeout"]
}

module "cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_SchedBDRSCheckRule"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"] && !local.isAutomationEnvironment
  event_target_arn               = module.scheduleBDRSCheck_lambda.arn
  expression                     = "rate(10 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.scheduleBDRSCheck_lambda.funcName
  tags                           = var.tags
}

module "sendToBDRS_queue" {
  source                   = "../modules/sqs"
  create_enable_events     = var.conditional-resources["create_enable_events"]
  name                     = "irsch_${var.env}_sendToBDRS"
  retention_period_seconds = 259200
  tags                     = var.tags
}

module "campaignSendToBDRS_queue" {
  source                   = "../modules/sqs"
  create_enable_events     = var.conditional-resources["create_enable_events"]
  name                     = "irsch_${var.env}_campaignSendToBDRS"
  retention_period_seconds = 259200
  tags                     = var.tags
}

module "campaignReceiveFromBDRS_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.bdrsResponse_lambda.arn
  lambda_function_name       = module.bdrsResponse_lambda.funcName
  name                       = "irsch_${var.env}_campaignReceiveFromBDRS"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.campaignReceiveFromBDRS_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.bdrsResponse_lambda.timeout * 6
}

module "campaignReceiveFromBDRS_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_campaignReceiveFromBDRS"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

//Mock BDRS setup for non PROD and DR environments
module "mockBDRS_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = contains(list("dev1","dev3", "q1a", "q2a"), var.env) ? var.lambda_concurrency : 1
  create_enable_events        = contains(list("dev1","dev3", "q1a", "q2a"), var.env) ? var.conditional-resources["create_enable_events"] : false
  create_lambda               = var.conditional-resources["create_mock_resources"]
  create_log_subscription     = contains(list("dev1","dev3", "q1a", "q2a"), var.env) ? var.conditional-resources["create_log_subscription"] : false
  description                 = "Mock BDRS setup for non-prod and dr environments."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.mockbdrs.irschMockBDRS.lambdaHandler"
  func_name                   = "irsch_${var.env}_MockBDRS"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "sendToMockBDRS_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = contains(list("dev1","dev3", "q1a", "q2a"), var.env) ? var.conditional-resources["create_enable_events"] : false
  create_enable_queue        = var.conditional-resources["create_mock_resources"]
  isLambdaFunction           = var.conditional-resources["create_mock_resources"]
  isLambdaTriggerNeeded      = var.conditional-resources["create_mock_resources"]
  lambda_function_arn        = module.mockBDRS_lambda.arn
  lambda_function_name       = module.mockBDRS_lambda.funcName
  name                       = "irsch_${var.env}_sendToMockBDRS"
  tags                       = var.tags
  visibility_timeout_seconds = module.mockBDRS_lambda.timeout
}

/****************************************************
Lambda, CW Resource for reference data processing
*****************************************************/
module "refdata_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Loads reference data into database."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.refdataloader.handler.RefDataLoaderHandler"
  func_name                   = "irsch_${var.env}_RefDataLoader"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "refDataCheck_Lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Checks for new reference data files."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.refdataloader.handler.SchedRefDataCheckHandler"
  func_name                   = "irsch_${var.env}_SchedRefDataCheck"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["1MinLambdaTimeout"]
}

module "refDataCheckRule_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_SchedRefDataCheckRule"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.refDataCheck_Lambda.arn
  expression                     = "rate(30 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.refDataCheck_Lambda.funcName
  tags                           = var.tags
}

/****************************************************
Lambda function && SNS Resources for SendNotification
*****************************************************/
module "sendNotification_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Sends emails to users about their requests."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.SendNotificationHandler"
  func_name                   = "irsch_${var.env}_SendNotification"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sns" {
  source                 = "../modules/sns"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  loggingRole_arn        = module.lambda_role.sns_logging_role_arn
  name                   = "irsch_${var.env}_InvokeNotificationLambda"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "subscribe_to_sns_InvokeNotificationLambda" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  isLambdaFunction     = true
  lambda_function_arn  = module.sendNotification_lambda.arn
  lambda_function_name = module.sendNotification_lambda.funcName
  sns_topic_arn        = module.sns.arn
}

/****************************************************
Lambdas for attachment processing
*****************************************************/
module "processUploadedAttachment_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Pushes incoming attachment to STP."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "irschProcessUploadedAttachment.lambdaHandler"
  func_name                   = "irsch_${var.env}_ProcessUploadedAttachment"
  layers                      = [module.sftpLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python36LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "processVirusScannedAttachment_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Process incoming file from STP after virus scan."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "irschProcessVirusScannedAttachment.lambdaHandler"
  func_name                   = "irsch_${var.env}_ProcessVirusScannedAttachment"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

/****************************************************
Lambda, CW, SQS Resources for STP Failure Process
*****************************************************/
module "processSTPFailureQueue_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Re-attempts push to STP in case STP was down."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "irschProcessSTPFailureQueue.lambdaHandler"
  func_name                   = "irsch_${var.env}_ProcessSTPFailureQueue"
  layers                      = [module.sftpLibraries_lambda_layer.arn]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python36LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "stpSendFailures_sqs" {
  source                    = "../modules/sqs"
  create_enable_events      = var.conditional-resources["create_enable_events"]
  isLambdaFunction          = true
  lambda_function_arn       = module.processSTPFailureQueue_lambda.arn
  lambda_function_name      = module.processSTPFailureQueue_lambda.funcName
  name                      = "irsch_${var.env}_STPSendFailures"
  receive_wait_time_seconds = 5
  tags                      = var.tags
}

module "processSTPFailureQueue_cloudwatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeProcessSTPFailureQueueFunc"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.processSTPFailureQueue_lambda.arn
  expression                     = "rate(15 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.processSTPFailureQueue_lambda.funcName
  tags                           = var.tags
}

/****************************************************
Start - CS Gateway Resources and API GW Implementation
*****************************************************/
module "submitResearchRequest_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Creates a new research request and case."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.submitcaseapi.submitCaseApilambda.handler"
  func_name                   = "irsch_${var.env}_SubmitResearchRequestApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveResearchAPI_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Queries details about a single case or request."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.retrieveresearchapi.retrieveResearchApilambda.handler"
  func_name                   = "irsch_${var.env}_RetrieveResearchApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "retrieveResearchSummaryAPI_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Queries summary request-level data for a submitter."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.retrieveresearchapi.retrieveResearchSummaryApilambda.handler"
  func_name                   = "irsch_${var.env}_RetrieveResearchSummaryApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "updateAndCloseApi_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Updates research results and closes a case."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateandcloseapi.updateAndCloseApiLambda.handler"
  func_name                   = "irsch_${var.env}_UpdateAndCloseApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "challengeCaseApi_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Allows an API user to challenge a case."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.challengecaseapi.challengeCaseApiLambda.handler"
  func_name                   = "irsch_${var.env}_ChallengeCaseApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "partnerRetrieveCaseApi_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Retrieve a single case for a researcher."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.retrieveresearchapi.partnerRetrieveCaseApiLambda.handler"
  func_name                   = "irsch_${var.env}_PartnerRetrieveCaseApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "partnerRetrieveCaseSummaryApi_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Retrieve case summary list for a researcher."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.retrieveresearchapi.partnerRetrieveCaseSummaryApiLambda.handler"
  func_name                   = "irsch_${var.env}_PartnerRetrieveCaseSummaryApi"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "gateway-cs" {
  source                   = "../modules/gateway-cs"
  domain_name              = lookup(var.cloudServices_api_aliases, var.env, "")
  gateway_name             = "irsch_${var.env}_cs"
  region                   = var.region
  regional_certificate_arn = lookup(var.cloudFront_api_cert_arn, var.env, "")
  stage_name               = "v1"
  tags                     = var.tags

  challengeCaseApi_lambda_arn                   = module.challengeCaseApi_lambda.arn
  challengeCaseApi_lambda_funcName              = module.challengeCaseApi_lambda.funcName
  partnerRetrieveCaseApi_lambda_arn             = module.partnerRetrieveCaseApi_lambda.arn
  partnerRetrieveCaseApi_lambda_funcName        = module.partnerRetrieveCaseApi_lambda.funcName
  partnerRetrieveCaseSummaryApi_lambda_arn      = module.partnerRetrieveCaseSummaryApi_lambda.arn
  partnerRetrieveCaseSummaryApi_lambda_funcName = module.partnerRetrieveCaseSummaryApi_lambda.funcName
  retrieveResearchSummary_lambda_arn            = module.retrieveResearchSummaryAPI_lambda.arn
  retrieveResearchSummary_lambda_funcName       = module.retrieveResearchSummaryAPI_lambda.funcName
  retrieveResearch_lambda_arn                   = module.retrieveResearchAPI_lambda.arn
  retrieveResearch_lambda_funcName              = module.retrieveResearchAPI_lambda.funcName
  submitResearchRequest_lambda_arn              = module.submitResearchRequest_lambda.arn
  submitResearchRequest_lambda_funcName         = module.submitResearchRequest_lambda.funcName
  updateAndCloseApi_lambda_arn                  = module.updateAndCloseApi_lambda.arn
  updateAndCloseApi_lambda_funcName             = module.updateAndCloseApi_lambda.funcName
}
module "cs-gateway_log_subscription"{
  source                    = "../modules/cloudwatch-subscription"
  create_log_subscription   = var.conditional-resources["create_log_subscription"]
  destination_func_arn      = module.esProcess_lambda.arn
  log_group_name            = "API-Gateway-Execution-Logs_${module.gateway-cs.id}/${module.gateway-cs.stage}"
  subscriptionFilter_prefix = "CSApiGW"
}
/****************************************************
End - CS Gateway Resources and API GW Implementation
*****************************************************/
/********************************************************
Lambda, CW, SQS Resources for Batch Request Process
*********************************************************/
module "submitCaseBatch_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Creates a new research request and case for batch usage when request does not have a DUNS."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.SubmitCaseHandler"
  func_name                   = "irsch_${var.env}_SubmitCaseForBatch"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "batchWatchService_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Handles batch-level state changes and notifications."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.batchwatchservice.batchWatchServiceLambda.handler"
  func_name                   = "irsch_${var.env}_BatchWatchService"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "submitCaseForBatch_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.submitCaseBatch_lambda.arn
  lambda_function_name       = module.submitCaseBatch_lambda.funcName
  name                       = "irsch_${var.env}_sendToSubmitCaseForBatch"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.submitCaseForBatch_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.submitCaseBatch_lambda.timeout * 6
}

module "submitCaseForBatch_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToSubmitCaseForBatch"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "batchDetail_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Records details on a batch request when no DUNS# is provided."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.BatchDetailHandler"
  func_name                   = "irsch_${var.env}_BatchDetail"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "submitCaseBatchParser_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Parses a batch file and submits BatchDetail requests."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.submitcaseapi.submitCaseBatchParser.handler"
  func_name                   = "irsch_${var.env}_SubmitCaseBatchParser"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "submitCaseBatchSubmitter_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Processes approved BatchDetail requests and submits SubmitCase requests."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.submitcaseapi.submitCaseBatchSubmitter.handler"
  func_name                   = "irsch_${var.env}_SubmitCaseBatchSubmitter"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sendToBatchDetail_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  delay_seconds              = 5
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.batchDetail_lambda.arn
  lambda_function_name       = module.batchDetail_lambda.funcName
  name                       = "irsch_${var.env}_sendToBatchDetail"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToBatchDetail_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.batchDetail_lambda.timeout * 6
}

module "sendToBatchDetail_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToBatchDetail"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToSubmitCaseBatchSubmitter_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.submitCaseBatchSubmitter_lambda.arn
  lambda_function_name       = module.submitCaseBatchSubmitter_lambda.funcName
  name                       = "irsch_${var.env}_sendToSubmitCaseBatchSubmitter"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToSubmitCaseBatchSubmitter_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.submitCaseBatchSubmitter_lambda.timeout * 6
}

module "sendToSubmitCaseBatchSubmitter_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToSubmitCaseBatchSubmitter"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToSubmitCaseBatchParser_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.submitCaseBatchParser_lambda.arn
  lambda_function_name       = module.submitCaseBatchParser_lambda.funcName
  name                       = "irsch_${var.env}_sendToSubmitCaseBatchParser"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToSubmitCaseBatchParser_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = 5400 //90 minutes
}

module "sendToSubmitCaseBatchParser_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToSubmitCaseBatchParser"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "batchDetailWithDuns_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Records details on a batch request when DUNS# is provided."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.BatchDetailHandler"
  func_name                   = "irsch_${var.env}_BatchDetailWithDuns"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "submitCaseForBatchWithDuns_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Creates a new research request and case for batch usage when request has DUNS."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.SubmitCaseHandler"
  func_name                   = "irsch_${var.env}_SubmitCaseForBatchWithDuns"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "sendToBatchDetailWithDuns_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  delay_seconds              = 5
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.batchDetailWithDuns_lambda.arn
  lambda_function_name       = module.batchDetailWithDuns_lambda.funcName
  name                       = "irsch_${var.env}_sendToBatchDetailWithDuns"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToBatchDetailWithDuns_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.batchDetailWithDuns_lambda.timeout * 6
}

module "sendToBatchDetailWithDuns_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToBatchDetailWithDuns"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToSubmitCaseForBatchWithDuns_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.submitCaseForBatchWithDuns_lambda.arn
  lambda_function_name       = module.submitCaseForBatchWithDuns_lambda.funcName
  name                       = "irsch_${var.env}_sendToSubmitCaseForBatchWithDuns"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToSubmitCaseForBatchWithDuns_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.submitCaseForBatchWithDuns_lambda.timeout * 6
}

module "sendToSubmitCaseForBatchWithDuns_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToSubmitCaseForBatchWithDuns"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "updateAndCloseBatchParser_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Parses incoming UpdateAndClose batch request file."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateandcloseapi.updateAndCloseBatchParserLambda.handler"
  func_name                   = "irsch_${var.env}_UpdateAndCloseBatchParser"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sendToUpdateAndCloseBatchParser_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.updateAndCloseBatchParser_lambda.arn
  lambda_function_name       = module.updateAndCloseBatchParser_lambda.funcName
  name                       = "irsch_${var.env}_sendToUpdateAndCloseBatchParser"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToUpdateAndCloseBatchParser_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.updateAndCloseBatchParser_lambda.timeout * 6
}

module "sendToUpdateAndCloseBatchParser_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToUpdateAndCloseBatchParser"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "updateAndCloseBatchGenerator_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates UpdateAndClose batch response file."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateandcloseapi.updateAndCloseBatchGeneratorLambda.handler"
  func_name                   = "irsch_${var.env}_UpdateAndCloseBatchGenerator"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["4MinLambdaTimeout"]
}

module "invokeUpdateAndCloseBatchGenerator_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeUpdateAndCloseBatchGeneratorLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.updateAndCloseBatchGenerator_lambda.arn
  expression                     = "rate(5 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.updateAndCloseBatchGenerator_lambda.funcName
  tags                           = var.tags
}

module "updateAndCloseForBatch_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Updates research results and closes a case, for batch requests."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateandcloseapi.updateAndCloseForBatchLambda.handler"
  func_name                   = "irsch_${var.env}_UpdateAndCloseForBatch"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "sendToUpdateAndCloseForBatch_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 10
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.updateAndCloseForBatch_lambda.arn
  lambda_function_name       = module.updateAndCloseForBatch_lambda.funcName
  name                       = "irsch_${var.env}_sendToUpdateAndCloseForBatch"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToUpdateAndCloseForBatch_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.updateAndCloseForBatch_lambda.timeout * 6
}

module "sendToUpdateAndCloseForBatch_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToUpdateAndCloseForBatch"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

/******************************************************
Lambda && SNS resources to process CW Alarm Events
*******************************************************/
data "archive_file" "ProcessCWAlarmEvents" {
  output_path = "../tmp/ProcessCWAlarmEvents.zip"
  source_dir  = "../lib/ProcessCWAlarmEvents"
  type        = "zip"
}
module "processCWAlarmEvents_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = false
  create_log_subscription     = false
  description                 = "Alarms we configured via cloudwatch are processed and email notifications are sent."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "index.handler"
  func_name                   = "irsch_${var.env}_ProcessCWAlarmEvents"
  memory                      = var.lambda_properties["1216MBLambdaMemory"]
  payload_filename            = data.archive_file.ProcessCWAlarmEvents.output_path
  funcName_that_consume_CWLog = null
  runtime                     = var.lambda_properties["nodejs10LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = "" //The alarm lambda should not have an alarm on its own unless needed
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
  tracing_config              = "PassThrough"

  variables = {
    "FromAddress" = contains(list("dr", "pd"), var.env) ? "iResearchPRODCWAlerts@dnb.com" : ""
    "ToAddress"   = contains(list("dr", "pd"), var.env) ? "iResearchDevSupport@DNB.com" : ""
  }
}

module "invokeProcessCWAlarmEventsLambda_sns" {
  source                 = "../modules/sns"
  create_enable_events   = false
  loggingRole_arn        = module.lambda_role.sns_logging_role_arn
  name                   = "irsch_${var.env}_InvokeProcessCWAlarmEventsLambda"
  sns_name_for_cwMonitor = ""
  tags                   = var.tags
}

module "subscribe_to_sns_InvokeProcessCWAlarmEventsLambda" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  isLambdaFunction     = true
  lambda_function_arn  = module.processCWAlarmEvents_lambda.arn
  lambda_function_name = module.processCWAlarmEvents_lambda.funcName
  sns_topic_arn        = module.invokeProcessCWAlarmEventsLambda_sns.arn
}

/*********************************************************
Lambda && SNS for Generate Research Notification
***********************************************************/
module "generateResearchNotification_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates notification events when a request is closed."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.ResearchNotificationHandler"
  func_name                   = "irsch_${var.env}_GenerateResearchNotification"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["1MinLambdaTimeout"]
}

module "invokeGenerateResearchNotificationLambda_sns" {
  source                 = "../modules/sns"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  loggingRole_arn        = module.lambda_role.sns_logging_role_arn
  name                   = "irsch_${var.env}_InvokeGenerateResearchNotificationLambda"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "subscribe_to_sns_InvokeGenerateResearchNotificationLambda" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  isLambdaFunction     = true
  lambda_function_arn  = module.generateResearchNotification_lambda.arn
  lambda_function_name = module.generateResearchNotification_lambda.funcName
  sns_topic_arn        = module.invokeGenerateResearchNotificationLambda_sns.arn
}

module "notifySystemOfEvent_sns" {
  source                 = "../modules/sns"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  loggingRole_arn        = module.lambda_role.sns_logging_role_arn
  name                   = "irsch_${var.env}_NotifySystemOfEvent"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

/************************************************************
MockLogon validation for non Production and DR environments
*************************************************************/
module "mockLogonValidation_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = false
  create_lambda               = contains(list("pd", "dr", "dev3"), var.env) ? false : true
  create_log_subscription     = false
  description                 = "Mock LogonValidation for non-prod and dr environments."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "mockGUIAuthenticationLambda.lambdaHandler"
  func_name                   = "irsch_${var.env}_MockLogonValidation"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = null
  runtime                     = var.lambda_properties["python36LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "mockDplus_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = local.isAutomationEnvironment
  concurrency                 = local.isAutomationEnvironment ? var.lambda_concurrency : 1
  create_enable_events        = local.isAutomationEnvironment
  create_lambda               = contains(list("pd", "dr", "dev3"), var.env) ? false : true
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Mock DPlus for non-prod and dr environments."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.testlambdas.handlers.MockDirectPlusDataHandler"
  func_name                   = "irsch_${var.env}_MockDplus"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = local.isAutomationEnvironment ? module.esProcess_lambda.funcName : null
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = local.isAutomationEnvironment ? module.invokeProcessCWAlarmEventsLambda_sns.name : ""
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "mockToken_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = local.isAutomationEnvironment
  concurrency                 = local.isAutomationEnvironment ? var.lambda_concurrency : 1
  create_enable_events        = local.isAutomationEnvironment
  create_lambda               = contains(list("pd", "dr", "dev3"), var.env) ? false : true
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Mock token for non-prod and dr environments."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.testlambdas.handlers.MockTokenHandler"
  func_name                   = "irsch_${var.env}_MockToken"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = local.isAutomationEnvironment ? module.esProcess_lambda.funcName : null
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = local.isAutomationEnvironment ? module.invokeProcessCWAlarmEventsLambda_sns.name : ""
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

module "mockGateway" {
  source                = "../modules/gateway-mocklogon"
  create_mockAPIGateway = contains(list("pd", "dr", "dev3"), var.env) ? false : true
  env                   = var.env
  region                = var.region
  tags                  = var.tags
  vpc_endpoints         = split(",", var.account_id == 292120075268 ? "vpce-02cc8c86fc2118650,vpce-0c6e790ade9e0d814,vpce-0c374831556b217dd" : var.account_id == 576929353350 ? "vpce-0dad1af25a7e08728" : "")

  mockDPlus_lambda_arn                = module.mockDplus_lambda.arn
  mockDPlus_lambda_funcName           = module.mockDplus_lambda.funcName
  mockLogonValidation_lambda_arn      = module.mockLogonValidation_lambda.arn
  mockLogonValidation_lambda_funcName = module.mockLogonValidation_lambda.funcName
  mockToken_lambda_arn                = module.mockToken_lambda.arn
  mockToken_lambda_funcName           = module.mockToken_lambda.funcName
}

/************************************************************
Lambda, CW Resources for Mini Investigation Process
*************************************************************/
module "miniInvestigationUsageProcessing_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates monthly billing and interco reports for mini request types."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.miniInvestigationReporting.miniInvestigationReportingServiceLambda.handler"
  func_name                   = "irsch_${var.env}_MiniInvestigationUsageProcessing"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "invokeminiInvestigationUsageProcessingLambda_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeMiniInvestigationUsageProcessingLambda"
  create_enable_cloudwatch_event = contains(list("pd", "dr"), var.env) ? true : false
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.miniInvestigationUsageProcessing_lambda.arn
  expression                     = "cron(0 13 16 * ? *)"
  isLambdaFunction               = contains(list("pd", "dr"), var.env) ? true : false
  lambda_function_name           = module.miniInvestigationUsageProcessing_lambda.funcName
  tags                           = var.tags
}

/************************************************************
Lambda, CW Resources for sending usage records to splunk
*************************************************************/
module "sendUsageSplunk_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Sends usage information to D+ Splunk."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.sendusagesplunk.sendUsageSplunkLambda.handler"
  func_name                   = "irsch_${var.env}_SendUsageSplunk"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "invokeSendUsageSplunkLambda_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeSendUsageSplunkLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.sendUsageSplunk_lambda.arn
  expression                     = contains(list("dr", "pd"), var.env) ? "rate(5 minutes)" : "rate(1 minute)"
  isLambdaFunction               = true
  lambda_function_name           = module.sendUsageSplunk_lambda.funcName
  tags                           = var.tags
}

/************************************************************
SQS Queue and SNS Subscription for sending usage data to Direct+
*************************************************************/
module "directPlusUsage_queue" {
  source                = "../modules/sqs"
  create_enable_events  = var.conditional-resources["create_enable_events"]
  isLambdaFunction      = false
  isLambdaTriggerNeeded = false
  kms_key_id            = module.sqs_kms.id
  lambda_function_arn   = ""
  lambda_function_name  = ""
  name                  = "irsch_${var.env}_DirectPlusUsage"
  requires_queue_policy = true
  tags                  = var.tags
  policy                = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.directPlusUsage_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
}

module "subscribe_to_NotifySystemOfEvent_for_directPlus" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.directPlusUsage_queue.arn
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_splunk_policy.json", { notificationTypeCode = 2, sendToSplunk = 1 })
}

/************************************************************
Lambda, SQS Resources for Submit To Remote App process
*************************************************************/
module "submitToRemoteApp_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Pushes a new or reassigned case to remote application queue."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.SubmitToRemoteAppHandler"
  func_name                   = "irsch_${var.env}_SubmitToRemoteApp"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "submitToRemoteApp_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  delay_seconds              = 5
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.submitToRemoteApp_lambda.arn
  lambda_function_name       = module.submitToRemoteApp_lambda.funcName
  name                       = "irsch_${var.env}_sendToSubmitToRemoteApp"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.submitToRemoteApp_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.submitToRemoteApp_lambda.timeout * 6
}

module "submitToRemoteApp_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToSubmitToRemoteApp"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

/************************************************************
SQS Queue for sending records to Unity Team
*************************************************************/
module "sendToUnity_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendToUnity"
  policy                     = templatefile("${path.module}/templates/sqs_access_to_teams_policy.json", { resource_queue_arn = module.sendToUnity_queue.arn, principals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr", "q2"), var.env) ? "259300059461" : "008635507388", local.accounts[contains(list("pd", "dr", "q2"), var.env) ? "259300059461" : "008635507388"])) })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 720
}

/*********************************************************
Start - SQS queues, and Topics for transactions to client partners
***********************************************************/
module "sendUpdateToDBIA_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToDBIA"
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToDBIA_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
}

module "subscribe_to_NotifySystemOfEvent_for_DBIA" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToDBIA_queue.arn
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 14182, notificationTypeCode = 2 })
}

module "sendUpdateToMyDnb_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToMyDnb"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToMyDnb_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_MyDnb" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 20645, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToMyDnb_queue.arn
}

module "sendUpdateToCredit_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToCredit"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToCredit_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_Credit" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 33587, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToCredit_queue.arn
}

module "sendUpdateToDNBi_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToDNBi"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToDNBi_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_DNBi" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 14186, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToDNBi_queue.arn
}

module "sendUpdateToDBAI_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToDBAI"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToDBAI_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_DBAI" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 12848, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToDBAI_queue.arn
}

module "sendUpdateToIRG_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToIRG"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToIRG_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_IRG" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 23607, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToIRG_queue.arn
}

module "sendUpdateToDunsTel_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToDunsTel"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToDunsTel_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_DunsTel" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 12842, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToDunsTel_queue.arn
}

module "sendUpdateToSupplierPortal_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToSupplierPortal"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToSupplierPortal_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_SupplierPortal" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 19677, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToSupplierPortal_queue.arn
}

module "sendUpdateToToolkit_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToToolkit"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToToolkit_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_Toolkit" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 15229, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToToolkit_queue.arn
}

module "sendUpdateToOnboardUI_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToOnboardUI"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToOnboardUI_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_OnboardUI" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 24970, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToOnboardUI_queue.arn
}

module "sendUpdateToDirect20_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToDirect20"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToDirect20_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_Direct20" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 26330, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToDirect20_queue.arn
}

module "sendUpdateToDNBiAus_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToDNBiAus"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToDNBiAus_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_DNBiAus" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 28411, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToDNBiAus_queue.arn
}

module "sendUpdateToOnboardAPI_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToOnboardAPI"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToOnboardAPI_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_OnboardAPI" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 29094, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToOnboardAPI_queue.arn
}

module "sendUpdateToCompliance_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToCompliance"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToCompliance_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_Compliance" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 14184, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToCompliance_queue.arn
}

/*********************************************************
End - SQS queues, and Topics for transactions to client partners
***********************************************************/
/************************************************************
Lambda, SQS Queue, CW and SNS Subscription Resources for sending usage data to VBO
*************************************************************/
module "sendUsageVBO_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Sends usage information to VBO."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.sendUsageVBO.sendUsageVBOLambda.handler"
  func_name                   = "irsch_${var.env}_SendUsageVBO"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["1MinLambdaTimeout"]
}

module "directPlusUsageVBO_queue" {
  source                = "../modules/sqs"
  create_enable_events  = var.conditional-resources["create_enable_events"]
  kms_key_id            = module.sqs_kms.id
  name                  = "irsch_${var.env}_DirectPlusUsageVBO"
  policy                = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.directPlusUsageVBO_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy = true
  tags                  = var.tags
}

module "invokeSendUsageVBOLambda_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeSendUsageVBOLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.sendUsageVBO_lambda.arn
  expression                     = contains(list("dr", "pd"), var.env) ? "rate(5 minutes)" : "rate(1 minute)"
  isLambdaFunction               = true
  lambda_function_name           = module.sendUsageVBO_lambda.funcName
  tags                           = var.tags
}

module "subscribe_to_NotifySystemOfEvent_for_DirectPlusUsageVBO" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_vbo_policy.json", { requestMethodCode = 34306, notificationTypeCode = 2, sendToVBO = 1 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.directPlusUsageVBO_queue.arn
}

/************************************************************
Lambda, SQS Queue, SNS Subscription and CW Resources for SFDC Usage Process
*************************************************************/
module "sfdcUsage_queue" {
  source                = "../modules/sqs"
  create_enable_events  = var.conditional-resources["create_enable_events"]
  kms_key_id            = module.sqs_kms.id
  name                  = "irsch_${var.env}_SFDCUsage"
  policy                = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sfdcUsage_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy = true
  tags                  = var.tags
}

module "subscribe_to_NotifySystemOfEvent_for_sfdc" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = "34487,36322", notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sfdcUsage_queue.arn
}

module "updateSFDC_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Updates SFDC on close of request."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.updateSFDC.updateSFDCLambda.handler"
  func_name                   = "irsch_${var.env}_UpdateSFDC"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "invokeUpdateSFDCLambda_cloudwatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeUpdateSFDCLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.updateSFDC_lambda.arn
  expression                     = contains(list("dr", "pd"), var.env) ? "rate(5 minutes)" : "rate(1 minute)"
  isLambdaFunction               = true
  lambda_function_name           = module.updateSFDC_lambda.funcName
  tags                           = var.tags
}

/*********************************************************
Lambda, CW Resources for Missing Event Monitor Processing
***********************************************************/
module "missingEventMonitor_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Report on missing events based on expected time on which the event should happen."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.missingEventMonitor.missingEventMonitorLambda.handler"
  func_name                   = "irsch_${var.env}_MissingEventMonitor"
  layers                      = [module.snowflakeLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["10MinLambdaTimeout"]
}

module "invokeMissingEventMonitor_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeMissingEventMonitor"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"] && !local.isAutomationEnvironment
  event_target_arn               = module.missingEventMonitor_lambda.arn
  expression                     = "rate(10 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.missingEventMonitor_lambda.funcName
  tags                           = var.tags
}

/*********************************************************
Lambda, CW Resources for STP Outbound and Inbound Processes
***********************************************************/
module "stpOutboundDelivery_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Puts outgoing files to STP."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.stpdelivery.stpOutboundDeliveryLambda.handler"
  func_name                   = "irsch_${var.env}_StpOutboundDelivery"
  layers                      = [module.sftpLibraries_py37_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "stpInboundDelivery_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Polls for incoming files from STP and processes them."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.stpdelivery.stpInboundDeliveryLambda.handler"
  func_name                   = "irsch_${var.env}_StpInboundDelivery"
  layers                      = [module.sftpLibraries_py37_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["4MinLambdaTimeout"]
}

module "invokeStpInboundDeliveryLambda_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeStpInboundDeliveryLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.stpInboundDelivery_lambda.arn
  expression                     = "rate(5 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.stpInboundDelivery_lambda.funcName
  tags                           = var.tags
}

module "invokeStpOutboundDeliveryLambda_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeStpOutboundDeliveryLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.stpOutboundDelivery_lambda.arn
  expression                     = "rate(5 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.stpOutboundDelivery_lambda.funcName
  tags                           = var.tags
}

/********************************************************
Lambda, CW, SQS Resources for Client Partners Integration - non API Solution
*********************************************************/
//Generate China File
module "generateChinaFile_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates file for China to send via stp the new China Mini cases."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.generatePartnerFile.generatePartnerFileLambda.handler"
  func_name                   = "irsch_${var.env}_GenerateChinaFile"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["10MinLambdaTimeout"]
}

module "invokeGenerateChinaFile_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeGenerateChinaFileLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.generateChinaFile_lambda.arn
  expression                     = contains(list("dr", "pd"), var.env) ? "cron(0 13 ? * MON-FRI *)" : "rate(10 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.generateChinaFile_lambda.funcName
  tags                           = var.tags
}

module "sendToChina_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  name                       = "irsch_${var.env}_sendToChina"
  tags                       = var.tags
  visibility_timeout_seconds = 600
}

//Generate Spain File
module "generateSpainFile_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates file for Spain to send."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.generatePartnerFile.generatePartnerFileLambda.handler"
  func_name                   = "irsch_${var.env}_GenerateSpainFile"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["10MinLambdaTimeout"]
}

module "invokeGenerateSpainFile_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeGenerateSpainFileLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.env == "pd" ? false : var.conditional-resources["create_enable_events"]
  event_target_arn               = module.generateSpainFile_lambda.arn
  expression                     = "rate(10 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.generateSpainFile_lambda.funcName
  tags                           = var.tags
}

module "sendToSpain_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  name                       = "irsch_${var.env}_sendToSpain"
  tags                       = var.tags
  visibility_timeout_seconds = 600
}

//Generate Andorra File
module "generateAndorraFile_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Generates file for Andorra to send."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.generatePartnerFile.generatePartnerFileLambda.handler"
  func_name                   = "irsch_${var.env}_GenerateAndorraFile"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["10MinLambdaTimeout"]
}

module "invokeGenerateAndorraFile_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeGenerateAndorraFileLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.env == "pd" ? false : var.conditional-resources["create_enable_events"]
  event_target_arn               = module.generateAndorraFile_lambda.arn
  expression                     = "rate(10 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.generateAndorraFile_lambda.funcName
  tags                           = var.tags
}

module "sendToAndorra_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  name                       = "irsch_${var.env}_sendToAndorra"
  tags                       = var.tags
  visibility_timeout_seconds = 600
}

/********************************************************
Lambda for Validate Update And Close
*********************************************************/
module "validateUpdateAndClose_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Checks that update and close request conforms to business validation rules."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "irsch/handlers/validateUpdateAndCloseLambda.handler"
  func_name                   = "irsch_${var.env}_ValidateUpdateAndClose"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/NodeLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["nodejs12LambdaRuntime"]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

/********************************************************
Cloud Watch Dashboard capturing Lambda, SNS, SQS, S3 Resource Usage
*********************************************************/
module "cw_dashboard" {
  source  = "../modules/cloudwatch-dashboard"
  db_name = var.env == "pd" ? "irsch-pd" : var.env == "dr" ? "irsch-pd-replica" : substr(var.env, 0, 1) == "q" ? "irsch-qa" : "iresearchdbase"
  env     = var.env
  region  = var.region
}

/********************************************************
Lambda, SQS Resources for CFP Parser
*********************************************************/
module "cfpParser_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Receives from stpInbound in order to assign a batch ID."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.cfp.cfpParserLambda.handler"
  func_name                   = "irsch_${var.env}_CfpParser"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "cfpResponseGenerator_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Creates response file with any validation failures to be stored in s3://datastores/sftp-outbound/cfp/."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.cfp.cfpResponseGeneratorLambda.handler"
  func_name                   = "irsch_${var.env}_CfpResponseGenerator"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sendToCFPParser_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.cfpParser_lambda.arn
  lambda_function_name       = module.cfpParser_lambda.funcName
  name                       = "irsch_${var.env}_sendToCFPParser"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToCFPParser_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.cfpParser_lambda.timeout * 6
}

module "sendToCFPParser_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToCFPParser"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToCFPResponseGenerator_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.cfpResponseGenerator_lambda.arn
  lambda_function_name       = module.cfpResponseGenerator_lambda.funcName
  name                       = "irsch_${var.env}_sendToCFPResponseGenerator"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToCFPResponseGenerator_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.cfpResponseGenerator_lambda.timeout * 6
}

module "sendToCFPResponseGenerator_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToCFPResponseGenerator"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sftp_server" {
  source                 = "../modules/sftpserver"
  create_sftp_server     = var.conditional-resources["create_sftp_server"]
  endpoint_type          = "VPC_ENDPOINT"
  identity_provider_type = "SERVICE_MANAGED"
  logging_role_arn       = module.lambda_role.sftp_server_cw_logs_role_arn
  tags                   = var.tags
  vpc_endpoint_id        = lookup(var.aws_sftp_server_vpc_end_points, var.env, "")
}

module "s3Object_cfpSftpUser_global_dir" {
  source                   = "../modules/s3-bucket-object"
  bucket_name              = module.datastores_s3.name
  object_key_on_the_bucket = "sftp-users/CFPUser${upper(var.env)}/Global/DONOTDELETE"
  source_of_the_object     = "../lib/DONOTDELETE"
}

module "s3Object_cfpSftpUser_domestic_dir" {
  source                   = "../modules/s3-bucket-object"
  bucket_name              = module.datastores_s3.name
  object_key_on_the_bucket = "sftp-users/CFPUser${upper(var.env)}/Domestic/DONOTDELETE"
  source_of_the_object     = "../lib/DONOTDELETE"
}

/********************************************************
Route 53 for AWS SFTP server
*********************************************************/
module "sftp_server_route53" {
  source                       = "../modules/route53"
  create_route53_record        = var.conditional-resources["create_sftp_server"]
  destination_endpoint_address = lookup(var.aws_sftp_server_vpc_end_point_dns_names, lookup(var.aws_sftp_server_vpc_end_points, var.env, ""), "")
  dns_zone                     = local.dns_zone
  name                         = "irsch-sftp-${var.env == "q1" ? "qa" : var.env == "q1a" ? "qaa" : var.env == "dev2" ? "dev" : var.env}.${local.dns_zone == null ? "" : local.dns_zone}"
  isAPrivateZone               = local.isAPrivateZone
}

/********************************************************
iResearch Maintenance & Admin Functionalities
*********************************************************/
module "fileBasedAdminRequest_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Processes Status Changes for Cases."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.fileadmin.fileBasedAdminLambda.handler"
  func_name                   = "irsch_${var.env}_FileBasedAdminRequest"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sftpOutboundDelivery_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Puts outgoing files to SFTP."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.stpdelivery.stpOutboundDeliveryLambda.handler"
  func_name                   = "irsch_${var.env}_SftpOutboundDelivery"
  layers                      = [module.sftpLibraries_py37_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "cfpSftpOutboundDelivery_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Puts outgoing files for CFP."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.stpdelivery.stpOutboundDeliveryLambda.handler"
  func_name                   = "irsch_${var.env}_CfpSftpOutboundDelivery"
  layers                      = [module.sftpLibraries_py37_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "invokeCfpStpOutboundDeliveryLambda_cw" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeCfpStpOutboundDeliveryLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.cfpSftpOutboundDelivery_lambda.arn
  expression                     = "rate(5 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.cfpSftpOutboundDelivery_lambda.funcName
  tags                           = var.tags
}

module "sftpInboundDelivery_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Polls for incoming files from SFTP and processes them."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.stpdelivery.stpInboundDeliveryLambda.handler"
  func_name                   = "irsch_${var.env}_SftpInboundDelivery"
  layers                      = [module.sftpLibraries_py37_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "invokeSftpOutboundDelivery_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeSftpOutboundDeliveryLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.sftpOutboundDelivery_lambda.arn
  expression                     = "rate(5 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.sftpOutboundDelivery_lambda.funcName
  tags                           = var.tags
}

module "invokeSftpInboundDelivery_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeSftpInboundDeliveryLambda"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.sftpInboundDelivery_lambda.arn
  expression                     = "rate(5 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.sftpInboundDelivery_lambda.funcName
  tags                           = var.tags
}

##############################################
# Auto Assign
##############################################
module "autoAssign_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = true
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Auto assigns cases to researcher/team based on geography or other factors."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.AutoAssignHandler"
  func_name                   = "irsch_${var.env}_AutoAssign"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["30SecLambdaTimeout"]
}

#######################################
# TakeRequestActionForBatch
#######################################
module "takeRequestActionForBatch_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Takes a request action for batches."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.lambdas.handlers.TakeRequestActionHandler"
  func_name                   = "irsch_${var.env}_TakeRequestActionForBatch"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "takeRequestActionForBatch_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToTakeRequestActionForBatch"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "takeRequestActionForBatch_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  delay_seconds              = 5
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.takeRequestActionForBatch_lambda.arn
  lambda_function_name       = module.takeRequestActionForBatch_lambda.funcName
  name                       = "irsch_${var.env}_sendToTakeRequestActionForBatch"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.takeRequestActionForBatch_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.takeRequestActionForBatch_lambda.timeout * 6
}

######################################
# CancelBatch
######################################
module "cancelBatch_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Cancels batches."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.CancelBatchHandler"
  func_name                   = "irsch_${var.env}_CancelBatch"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sendToCancelBatch_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToCancelBatch"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToCancelBatch_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.cancelBatch_lambda.arn
  lambda_function_name       = module.cancelBatch_lambda.funcName
  name                       = "irsch_${var.env}_sendToCancelBatch"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToCancelBatch_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.cancelBatch_lambda.timeout * 6
}

#######################
# Ascent Exclusions
#######################
module "sendUpdateToAscentExclusions_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToAscentExclusions"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_and_team_access_policy.json", { resource_queue_arn = module.sendUpdateToAscentExclusions_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn, principals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623", local.accounts[contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623"]))})
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_AscentExclusions" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 35935, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToAscentExclusions_queue.arn
}

#######################
# Ascent Violations
#######################
module "sendUpdateToAscentViolations_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToAscentViolations"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_and_team_access_policy.json", { resource_queue_arn = module.sendUpdateToAscentViolations_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn, principals = join("\",\"", formatlist("arn:aws:iam::%s:role/%s", contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623", join("-",list("violations",local.accounts[contains(list("pd", "dr"), var.env) ? "352946570319" : var.env == "q2a" ? "431314012798" : var.env == "q2" ? "747052504686" : contains(list("q1", "q1a"), var.env) ? "484330945175" : "674031437623"]))))})
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_AscentViolations" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 36124, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToAscentViolations_queue.arn
}

#######################
# Admin Reporting
#######################
module "adminReporting_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Admin Reporting."
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "lambdas.adminReporting.adminReportingLambda.handler"
  func_name                   = "irsch_${var.env}_AdminReporting"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "invokeAdminReporting_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeAdminReportingLambda"
  create_enable_cloudwatch_event = var.env == "pd" ? true : false
  create_enable_events           = var.conditional-resources["create_enable_events"]
  event_target_arn               = module.adminReporting_lambda.arn
  //expression                     = var.env == "pd" ? "cron(0 23 L * ? *)" : "cron(0 23 * * ? *)"
  expression                     = "cron(0 23 * * ? *)"
  isLambdaFunction               = true
  lambda_function_name           = module.adminReporting_lambda.funcName
  tags                           = var.tags
}

#######################
# Ascent SAMUEI
#######################
module "sendUpdateToAscentSAMUEI_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  kms_key_id                 = module.sqs_kms.id
  name                       = "irsch_${var.env}_sendUpdateToAscentSAMUEI"
  policy                     = templatefile("${path.module}/templates/sns_to_sqs_access_policy.json", { resource_queue_arn = module.sendUpdateToAscentSAMUEI_queue.arn, source_sns_arn = module.notifySystemOfEvent_sns.arn })
  requires_queue_policy      = true
  tags                       = var.tags
  visibility_timeout_seconds = 1800
}

module "subscribe_to_NotifySystemOfEvent_for_AscentSAMUEI" {
  source               = "../modules/sns-subscription"
  create_enable_events = var.conditional-resources["create_enable_events"]
  filter_policy        = templatefile("${path.module}/templates/sns_filter_with_out_vbo_policy.json", { requestMethodCode = 36186, notificationTypeCode = 2 })
  isLambdaFunction     = false
  isSQS                = true
  sns_topic_arn        = module.notifySystemOfEvent_sns.arn
  sqsQueue_arn         = module.sendUpdateToAscentSAMUEI_queue.arn
}

#######################
# BatchWatchCondenser
#######################
module "batchWatchCondenser_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Used to condense batch records submitted to iResearch"
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  func_handler                = "lambdas.batchwatchservice.batchWatchCondenserLambda.handler"
  func_name                   = "irsch_${var.env}_BatchWatchCondenser"
  layers                      = [module.apiLibraries_lambda_layer.arn, ""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["2MinLambdaTimeout"]
}

module "batchWatchPreQueue_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 10000
  batching_window_in_seconds = 120
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.batchWatchCondenser_lambda.arn
  lambda_function_name       = module.batchWatchCondenser_lambda.funcName
  name                       = "irsch_${var.env}_BatchWatchPreQueue"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.batchWatchPreQueue_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = 12 * 60
}

module "batchWatchPreQueue_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_BatchWatchPreQueue"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToBatchWatchService_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  batching_window_in_seconds = 120
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.batchWatchService_lambda.arn
  lambda_function_name       = module.batchWatchService_lambda.funcName
  name                       = "irsch_${var.env}_sendToBatchWatchService"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToBatchWatchService_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = 12 * 60
}

module "sendToBatchWatchService_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToBatchWatchService"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

#######################
# Reporting Extract
#######################
module "snowflake_load_s3" {
  source          = "../modules/s3"
  isVersioned     = false
  lifecycle_rules = var.snowflake_load_s3bucket_lifecycle_rules
  s3_bucket_name  = "irsch-${var.env}-snowflake-load"
  tags            = var.tags
}

module "rptgExtractController_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = 1
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Used to condense batch records submitted to iResearch"
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  func_handler                = "lambdas.rptgextractcontroller.rptgExtractControllerLambda.handler"
  func_name                   = "irsch_${var.env}_RptgExtractController"
  layers                      = [module.apiLibraries_lambda_layer.arn,""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "rptgExtractorCase_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Used to condense batch records submitted to iResearch"
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.RptgExtractorCaseHandler"
  func_name                   = "irsch_${var.env}_RptgExtractorCase"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sendToRptgExtractorCase_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 5000
  batching_window_in_seconds = 60
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.rptgExtractorCase_lambda.arn
  lambda_function_name       = module.rptgExtractorCase_lambda.funcName
  name                       = "irsch_${var.env}_sendToRptgExtractorCase"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToRptgExtractorCase_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.rptgExtractorCase_lambda.timeout * 6 // 6 times the function time out
}

module "sendToRptgExtractorCase_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToRptgExtractorCase"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToRptgExtractController_queue" {
  source                     = "../modules/sqs"
  batch_size                 = 1
  batching_window_in_seconds = 0
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.rptgExtractController_lambda.arn
  lambda_function_name       = module.rptgExtractController_lambda.funcName
  name                       = "irsch_${var.env}_sendToRptgExtractController"
  tags                       = var.tags
  visibility_timeout_seconds = module.rptgExtractController_lambda.timeout * 6 // 6 times the function time out
}

module "invokeRptgExtractController_cloudWatch" {
  source                         = "../modules/cloudwatch-event"
  cloudwatch_event_name          = "irsch_${var.env}_InvokeRptgExtractController"
  create_enable_cloudwatch_event = true
  create_enable_events           = var.conditional-resources["create_enable_events"] && !local.isAutomationEnvironment
  event_target_arn               = module.rptgExtractController_lambda.arn
  expression                     = "rate(15 minutes)"
  isLambdaFunction               = true
  lambda_function_name           = module.rptgExtractController_lambda.funcName
  tags                           = var.tags
}
###############################
## Lambda Warmer function
###############################
data "archive_file" "lambdaWarmer" {
  output_path = "../tmp/LambdaWarmer.zip"
  source_dir  = "../lib/lambda-warmer"
  type        = "zip"
}
module "lambdaWarmer_lambda" {
  source                      = "../modules/lambda"
  enable_keepwarm             = false
  concurrency                 = var.lambda_concurrency
  create_enable_events        = false
  create_log_subscription     = false
  description                 = "Helps keep the lambda functions warm"
  execution_role_arn          = module.lambda_role.role_arn
  func_handler                = "index.handler"
  func_name                   = "irsch_${var.env}_LambdaWarmer"
  memory                      = var.lambda_properties["128MBLambdaMemory"]
  payload_filename            = data.archive_file.lambdaWarmer.output_path
  funcName_that_consume_CWLog = null
  runtime                     = var.lambda_properties["nodejs14LambdaRuntime"]
  tags                        = var.tags
  timeout                     = var.lambda_properties["15SecLambdaTimeout"]
}

###########################################################################
## DFF Related work
###########################################################################
module "dff_requests_s3" {
  source          = "../modules/s3"
  isVersioned     = false
  s3_bucket_name  = "irsch-${var.env}-dff-requests"
  tags            = var.tags
}

module "dffSubmitCaseBatchParser_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Parses a batch file and submits BatchDetail requests submitted by DFF team"
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  func_handler                = "lambdas.submitcaseapi.dffSubmitCaseBatchParserLambda.handler"
  func_name                   = "irsch_${var.env}_DffSubmitCaseBatchParser"
  layers                      = [module.apiLibraries_lambda_layer.arn,""]
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/AuthorizationLambdas.zip"
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["15MinLambdaTimeout"]
}

module "sendToDffSubmitCaseBatchParser_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.dffSubmitCaseBatchParser_lambda.arn
  lambda_function_name       = module.dffSubmitCaseBatchParser_lambda.funcName
  name                       = "irsch_${var.env}_sendToDffSubmitCaseBatchParser"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.sendToDffSubmitCaseBatchParser_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.dffSubmitCaseBatchParser_lambda.timeout * 6
  batch_size                 = 1
}

module "sendToDffSubmitCaseBatchParser_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_sendToDffSubmitCaseBatchParser"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

###########################
#BDRS ICW New Duns
##########################
module "bdrsResponseDataEntry_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_log_subscription     = var.conditional-resources["create_log_subscription"]
  description                 = "Function that handles the BDRS Response for Data Entry App"
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = module.esProcess_lambda.funcName
  func_handler                = "com.dnb.irsch.eventdrivenlambdas.handlers.BDRSDataEntryResponseHandler"
  func_name                   = "irsch_${var.env}_BDRSResponseDataEntry"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/Lambdas.jar"
  runtime                     = var.lambda_properties["java11LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  sns_name_for_cwMonitor      = module.invokeProcessCWAlarmEventsLambda_sns.name
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["5MinLambdaTimeout"]
}

module "receiveFromBDRSDataEntry_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_enable_events"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.bdrsResponseDataEntry_lambda.arn
  lambda_function_name       = module.bdrsResponseDataEntry_lambda.funcName
  name                       = "irsch_${var.env}_receiveFromBDRSDataEntry"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.receiveFromBDRSDataEntry_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.bdrsResponseDataEntry_lambda.timeout * 6
}

module "receiveFromBDRSDataEntry_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_enable_events"]
  name                   = "irsch_${var.env}_DLQ_receiveFromBDRSDataEntry"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.name
  tags                   = var.tags
}

module "sendToBDRSDataEntry_queue" {
  source                   = "../modules/sqs"
  create_enable_events     = var.conditional-resources["create_enable_events"]
  name                     = "irsch_${var.env}_sendToBDRSDataEntry"
  tags                     = var.tags
}

/************************************************************
Elastic Search Case Extract Domain and the necessary resources
*************************************************************/

module "esCaseExtract_domain" {
  source                      = "../modules/elasticsearch"
  account_id                  = var.account_id
  cognito_access_iam_role_arn = ""
  cognito_identity_pool_id    = module.es_kibana_cognito_pool.cognito_identity_pool_id
  cognito_user_pool_id        = module.es_kibana_cognito_pool.cognito_user_pool_id
  create_enable_events        = var.conditional-resources["create_enable_events"]
  create_esDomain             = var.conditional-resources["create_case_extract_domain"]
  domain_name                 = "irsch-${var.env}-caseExtract-domain"
  domain_version              = "6.5"
  ebs_enabled                 = true
  enable_authentication       = false
  encrypt_at_rest             = true
  instance_count              = var.env == "pd" ? 2 : 1
  instance_type               = "t3.medium.elasticsearch"
  iops                        = 0
  security_group_ids          = module.es_security_group.securityGroup_id
  sns_arn_for_cwMonitor       = module.invokeProcessCWAlarmEventsLambda_sns.arn
  subnet_ids                  = list(var.lambda_subnets[0])
  tags                        = var.tags
  volume_size                 = var.env == "pd" ? 500 : 100
  volume_type                 = "gp2"
  //cognito_access_iam_role_arn   = "arn:aws:iam::${var.account_id}:role/service-role/CognitoAccessForAmazonES"
}

module "esCaseExtract_queue" {
  source                     = "../modules/sqs"
  create_enable_events       = var.conditional-resources["create_case_extract_domain"]
  isLambdaFunction           = true
  isLambdaTriggerNeeded      = true
  lambda_function_arn        = module.esCaseExtract_lambda.arn
  lambda_function_name       = module.esCaseExtract_lambda.funcName
  name                       = "irsch_${var.env}_esCaseExtract"
  redrive_policy             = "{\"deadLetterTargetArn\":\"${module.esCaseExtract_dlq_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = var.tags
  visibility_timeout_seconds = module.bdrsResponse_lambda.timeout * 6
}

module "esCaseExtract_dlq_queue" {
  source                 = "../modules/sqs"
  create_enable_events   = var.conditional-resources["create_case_extract_domain"]
  name                   = "irsch_${var.env}_DLQ_esCaseExtract"
  sns_name_for_cwMonitor = module.invokeProcessCWAlarmEventsLambda_sns.arn
  tags                   = var.tags
}

module "esCaseExtract_lambda" {
  source                      = "../modules/lambda"
  concurrency                 = var.lambda_concurrency != -1 ? var.lambda_concurrency * 2 : var.lambda_concurrency
  create_enable_events        = false
  create_lambda               = var.conditional-resources["create_case_extract_domain"]
  create_log_subscription     = false
  description                 = "Case extract logs are consumed and sent over to ES."
  enable_keepwarm             = false
  execution_role_arn          = module.lambda_role.role_arn
  funcName_that_consume_CWLog = null
  func_handler                = "index.lambda_handler"
  func_name                   = "irsch_${var.env}_esCaseExtract"
  memory                      = var.lambda_properties["3GBLambdaMemory"]
  payload_filename            = "../lib/CaseExtractLambdas.zip"
  runtime                     = var.lambda_properties["python37LambdaRuntime"]
  security_group_ids          = [module.lambda_security_group.securityGroup_id]
  subnets                     = var.lambda_subnets
  tags                        = var.tags
  timeout                     = var.lambda_properties["4MinLambdaTimeout"]
  tracing_config              = "PassThrough"

  variables = {
    "ES_ENDPOINT" = module.es_domain.endpoint
  }
}