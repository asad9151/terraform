## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12 |

## Providers

No provider.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| env | The environment. (i.e. pd\|d2\|q1) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| account\_id | The Account ID for POC or USSShared. |
| conditional-resources | The map of flags to decide on creating resources based on environment. |
| lambda\_concurrency | The number of lambda concurrency based on the environment of the function. |
| lambda\_properties | n/a |
| lambda\_subnets | The subnet based on the environment. |
| mysql-subnets | The database subnet based on environment. |
| project | The project prefix. |
| region | The AWS region for the resources based on the environment. |
| remotestaterepo | The bucket name for the Terraform state file based on environment. |
| tags | Tags used on resources for billing. |
| vpc\_id | The VPC of the resources based on the environment. |
