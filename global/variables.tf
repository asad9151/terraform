variable "env" {
  description = "Variable to specify environment shortname to pick the right environment files"
}

variable "region" {
  default = "us-east-1"
}

variable "account_id" {
  type        = number
  description = "the account id in which we are running the scripts against"
}

variable "lambda_subnets" {
  type        = list(string)
  description = "subnets in which the lambda functions are to be created"
}

variable "lambda_properties" {
  type        = map(string)
  description = "different properties(timeout, memory ...) of lambda functions constructed into a map"
}

variable "lambda_concurrency" {
  type        = number
  description = "maximum number of lambda functions of the same can be run at one instance"
}
variable "vpc_id" {
  type        = string
  description = "the vpc id under which all the resources are to be created"
}

variable "cloudFront_aliases" {
  type = map(string)

  default = {
    pd       = "www.iresearch.dnb.com"
    dev2     = "www-dev2.iresearch.dnb.com"
    q1       = "www-qa.iresearch.dnb.com"
    q1uitest = "www-qauitest.iresearch.dnb.com"
    q2       = "www-stg.iresearch.dnb.com"
  }
}

variable "cloudFront_api_cert_arn" {
  type = map(string)

  default = {
    pd        = "arn:aws:acm:us-east-1:292120075268:certificate/1cfe19d2-1378-4da4-a5b3-2e902c1ab46e"
    dev2      = "arn:aws:acm:us-east-1:576929353350:certificate/7951bb05-bc75-4238-ae40-eefdcc9473f5"
    q1        = "arn:aws:acm:us-east-1:292120075268:certificate/8a5d043a-5c93-44ec-9430-c48429147cff"
    q1uitest  = "arn:aws:acm:us-east-1:292120075268:certificate/8a5d043a-5c93-44ec-9430-c48429147cff"
    q1a       = "arn:aws:acm:us-east-1:292120075268:certificate/8a5d043a-5c93-44ec-9430-c48429147cff"
    q2        = "arn:aws:acm:us-east-1:292120075268:certificate/0f497eb3-c63c-4ce4-9a30-e3c632d732d8"
    q2a       = "arn:aws:acm:us-east-1:292120075268:certificate/0f497eb3-c63c-4ce4-9a30-e3c632d732d8"
  }
}

variable "datastores_s3bucket_cors_rule" {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    max_age_seconds = number
  }))

  default = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "HEAD"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    },
  ]
}

variable "datastores_s3bucket_lifecycle_rules" {
  type = list(object({
    enabled = bool
    id      = string
    prefix  = string
    expiration = list(object({
      days = number
    }))
    noncurrent_version_transition = list(object({
      days          = number
      storage_class = string
    }))
    noncurrent_version_expiration = list(object({
      days = number
    }))
  }))

  default = [
    {
      enabled = true
      id      = "FirmographicsExpire"
      prefix  = "firmographics/"

      expiration = [{
        days = 1
      }]
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 1
      }]
    },
    {
      enabled = true
      id      = "expire-attachment-upload"
      prefix  = "attachment-upload"
      expiration = [{
        days = 2
      }]
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 1
      }]
    },
    {
      enabled                       = true
      id                            = "ExpireOlderObjects"
      prefix                        = ""
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 5
      }]
    },
  ]
}

variable "tags" {
  type = map(string)
}

variable "cloudServices_api_aliases" {
  type = map(string)

  default = {
    pd    = "api.iresearch.dnb.com"
    dev2  = "api-dev2.iresearch.dnb.com"
    q1    = "api-qa.iresearch.dnb.com"
    q2    = "api-stg.iresearch.dnb.com"
    q1a   = "api-qaa.iresearch.dnb.com"
    q2a   = "api-stga.iresearch.dnb.com"
  }
}

variable "mysql-subnetIds" {
  type    = list(string)
  default = []
}

variable "refdata_s3bucket_lifecycle_rules" {
  type = list(object({
    enabled = bool
    prefix  = string
    id      = string

    expiration = list(object({
      days = number
    }))
    noncurrent_version_transition = list(object({
      days          = number
      storage_class = string
    }))
    noncurrent_version_expiration = list(object({
      days = number
    }))

  }))

  default = [
    {
      enabled                       = true
      prefix                        = "applicationconfig/"
      id                            = "ApplicationConfig"
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 30
      }]
    },
    {
      enabled                       = true
      prefix                        = "countryImport/"
      id                            = "CountryImport"
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 30
      }]
    },
    {
      enabled                       = true
      prefix                        = "countryresearchtypes/"
      id                            = "CountryResearchTypes"
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 30
      }]
    },
    {
      enabled                       = true
      prefix                        = "routingrules/"
      id                            = "RoutingRules"
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 30
      }]
    },
    {
      enabled                       = true
      prefix                        = "creditactive/"
      id                            = "CreditActive"
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 150
      }]
    },
    {
      enabled                       = true
      prefix                        = "CCPA/"
      id                            = "CCPA"
      expiration                    = []
      noncurrent_version_transition = []
      noncurrent_version_expiration = [{
        days = 120
      }]
    },
    {
      enabled    = true
      prefix     = "geo/"
      id         = "GEO"
      expiration = []
      noncurrent_version_transition = [{
        days          = 7
        storage_class = "GLACIER"
      }]
      noncurrent_version_expiration = [{
        days = 97
      }]
    },
    {
      enabled    = true
      prefix     = "scots/"
      id         = "SCOTS"
      expiration = []
      noncurrent_version_transition = [{
        days          = 7
        storage_class = "GLACIER"
      }]
      noncurrent_version_expiration = [{
        days = 97
      }]
    },
  ]
}

variable "aws_sftp_server_vpc_end_points" {
  type = map(string)

  default = {
    pd   = "vpce-027df97ed0b2eaec2"
    dev2 = "vpce-095038223418387f0"
    q1   = "vpce-049db6ed1a4dac77e"
    dr   = "vpce-0451a46ad7b689dad"
  }
}

variable "route53_dns_zone" {
  type = map(string)

  default = {
    576929353350 = "dev.irs.dnb.net"
    292120075268 = "irs.dnb.net"
  }
}

variable "aws_sftp_server_vpc_end_point_dns_names" {
  type = map(string)

  default = {
    "vpce-095038223418387f0" = "vpce-095038223418387f0-p8utif6z.server.transfer.us-east-1.vpce.amazonaws.com"
    "vpce-049db6ed1a4dac77e" = "vpce-049db6ed1a4dac77e-bcuh70ic.server.transfer.us-east-1.vpce.amazonaws.com"
    "vpce-027df97ed0b2eaec2" = "vpce-027df97ed0b2eaec2-gjhnlrk6.server.transfer.us-east-1.vpce.amazonaws.com"
    "vpce-0451a46ad7b689dad" = "vpce-0451a46ad7b689dad-ke8f580x.server.transfer.us-west-2.vpce.amazonaws.com"
  }

  description = "Variable that contains the (one of) dns name of vpc end point mapped to vpc endpoint id"
}

variable "conditional-resources" {
  description = "The map of flags, help to decide the creation of resources based on environment."
  type        = map(string)
}

variable "snowflake_load_s3bucket_lifecycle_rules" {
  type = list(object({
    enabled = bool
    id = string
    prefix = string
    expiration = list(object({
      days = number
    }))
    noncurrent_version_transition = list(object({
      days          = number
      storage_class = string
    }))
    noncurrent_version_expiration = list(object({
      days = number
    }))
  }))

  default = [
    {
      id      = "EntireBucket"
      enabled = true
      prefix = ""
      expiration = [{
        days = 30
    }]
      noncurrent_version_transition = []
      noncurrent_version_expiration = []
    }
  ]
}

variable "snowflake_sqs" {
  description = "SQS ARNs at snowflake to receive events from our S3 bucket"
  type = map(string)
  default = {
    d2 = "arn:aws:sqs:us-east-1:139316230315:sf-snowpipe-AIDASA37E7CV6GLLWXRCG-NMyS9959pekOBKb4wl2P6Q"
    q1 = "arn:aws:sqs:us-east-1:514725262562:sf-snowpipe-AIDAXPWAEGTRMF6HNNN64-mxlnW0YXuSNd5XXSaui5nw"
    q2 = "arn:aws:sqs:us-east-1:678821797270:sf-snowpipe-AIDAZ4DHOTWLNJFX3VEQG-ee765d3livwzi-h6IV9a_A"
    pd = "arn:aws:sqs:us-east-1:514725262562:sf-snowpipe-AIDAXPWAEGTRDLZ3DSAAA-a0N8uyYaSSwP3Y1lHMeR1g"
    dev1 = "arn:aws:sqs:us-east-1:139316230315:sf-snowpipe-AIDASA37E7CV6GLLWXRCG-NMyS9959pekOBKb4wl2P6Q"
  }
}