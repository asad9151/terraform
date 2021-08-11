//Generate the tags to be used across all platforms
locals {
  application_tags = {
    CostCenter         = "6875"
    ProjectName        = "Columbo iResearch"
    DataClassification = "Commercial In Confidence"
    Environment        = substr(var.env, 0, 1) == "p" ? "PRODUCTION" : var.env == "stg" ? "STAGING" : substr(var.env, 0, 1) == "q" ? "QA" : substr(var.env, 0, 2) == "dr" ? "DR" : "Development"
  }

  ensono_tags = {
    usshared = {
      EnsonoSupportLevel = "Fully Managed"
      Monitoring         = "datadog"
      EnsonoPatching     = "automated"
      reimagine          = "baselineJuly2019"
    }
    dev = {}
  }

  common_tags = merge(
    local.application_tags,
    local.ensono_tags[local.application_tags["Environment"] != "Development" ? "usshared" : "dev"],
  )
}

//Lambda Properties
locals {
  lambda_properties = {
    "1216MBLambdaMemory"  = 1216
    "1MinLambdaTimeout"   = 60
    "2MinLambdaTimeout"   = 120
    "4MinLambdaTimeout"   = 240
    "30SecLambdaTimeout"  = 30
    java8LambdaRuntime    = "java8"
    java11LambdaRuntime   = "java11"
    "3GBLambdaMemory"     = 3008
    "5MinLambdaTimeout"   = 300
    "15MinLambdaTimeout"  = 900
    python36LambdaRuntime = "python3.6"
    python37LambdaRuntime = "python3.7"
    "256MBLambdaMemory"   = 256
    "10MinLambdaTimeout"  = 600
    nodejs12LambdaRuntime = "nodejs12.x"
    nodejs10LambdaRuntime = "nodejs10.x"
    "128MBLambdaMemory"   = 128
    nodejs14LambdaRuntime = "nodejs14.x"
    "15SecLambdaTimeout"  = 15
  }
}

//account id
locals {
  accounts_map = {
    dev      = 576929353350
    usshared = 292120075268
  }

  account_id = local.application_tags["Environment"] == "Development" ? local.accounts_map["dev"] : local.accounts_map["usshared"]
}

//lambda concurrency
locals {
  //default concurrency values based on environment - these can be overridden/updated at each lambda function
  concurrency_map = {
    prod      = 15
    other-env = 10
    dev       = -1
  }

  concurrency = local.application_tags["Environment"] == "Development" ? local.concurrency_map["dev"] : local.application_tags["Environment"] == "PRODUCTION" ? local.concurrency_map["prod"] : local.concurrency_map["other-env"]
}

//lambda subnets
locals {
  subnets_map = {
    dev  = "subnet-076e1285fe707db99,subnet-08463cf8ce394628d,subnet-04eaf8c5be31c0bed"
    qa   = "subnet-906b03c9,subnet-08315f51"
    stg  = "subnet-906b03c9,subnet-08315f51"
    prod = "subnet-e5dd9792,subnet-cd0e6094"
    dr   = "subnet-30468a6a,subnet-69475b0f,subnet-9ba894d3"
  }

  subnet = split(
    ",",
    var.env == "dr" ? local.subnets_map["dr"] : var.env == "pd" ? local.subnets_map["prod"] : var.env == "stg" ? local.subnets_map["stg"] : substr(var.env, 0, 1) == "d" ? local.subnets_map["dev"] : substr(var.env, 0, 1) == "q" ? local.subnets_map["qa"] : "",
  )
}

//vpc id
locals {
  vpc_map = {
    dev  = "vpc-0b94f9bb9f5e4e98d"
    qa   = "vpc-d4003bb1"
    stg  = "vpc-59d5b53c"
    prod = "vpc-10043f75"
    dr   = "vpc-c9954bb0"
  }

  vpc = var.env == "dr" ? local.vpc_map["dr"] : var.env == "pd" ? local.vpc_map["prod"] : var.env == "stg" ? local.vpc_map["stg"] : substr(var.env, 0, 1) == "d" ? local.vpc_map["dev"] : substr(var.env, 0, 1) == "q" ? local.vpc_map["qa"] : ""
}

//remote state repo
locals {
  backendS3BucketNames_map = {
    dev  = "com.dnb.tds.576929353350.dev"
    qa   = "com.dnb.dot.infrastructure.qa"
    stg  = "com.dnb.dot.infrastructure.stg"
    prod = "com.dnb.dot.infrastructure.prd"
    dr   = "com.dnb.dot.infrastructure.dr"
  }

  backendS3BucketName = var.env == "dr" ? local.backendS3BucketNames_map["dr"] : var.env == "pd" ? local.backendS3BucketNames_map["prod"] : var.env == "stg" ? local.backendS3BucketNames_map["stg"] : substr(var.env, 0, 1) == "d" ? local.backendS3BucketNames_map["dev"] : substr(var.env, 0, 1) == "q" ? local.backendS3BucketNames_map["qa"] : ""
}

//project Name
locals {
  project = "irsch"
}

//region
locals {
  regions_map = {
    default = "us-east-1"
    dr      = "us-west-2"
  }

  region = var.env == "dr" ? local.regions_map["dr"] : local.regions_map["default"]
}

//mysql subnets
locals {
  mysqlSubnets_map = {
    dr = "subnet-f3405c95,subnet-4eac9006,subnet-bb428ee1"
    dev = "subnet-0bfc180836d47d538,subnet-0754d52e8bfe8ab4d,subnet-07eb405c238ddc45b"
  }

  mysql-subnets = split(",", var.env == "dr" ? local.mysqlSubnets_map["dr"] : substr(var.env, 0, 1) == "d" ? local.mysqlSubnets_map["dev"] : "")
}

//Decision Logic for resources to be created in certain environments
locals {
  conditional_resources = {
    create_es_domain         = contains(list("q1", "q2", "pd"), var.env) ? true : false
    create_log_subscription  = contains(list("dr", "dev1", "dev2", "dev3"), var.env) ? false : true
    //create_db_param_group    = contains(list("dev2", "q1", "pd", "dr"), var.env) ? true : false
    create_db_subnet_group   = contains(list("dev2","dr"), var.env) ? true : false
    create_database          = contains(list("q1", "pd", "dr","dev2"), var.env) ? true : false
    create_enable_events     = var.env == "dr" ? false : true
    create_mock_resources    = contains(list("pd", "dr"), var.env) ? false : true
    create_sftp_server       = contains(list("dev2","q1", "pd"), var.env) ? true : false
  }
}