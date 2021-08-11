### Project Title
iResearch ISAAC - The repository contains the terraform scripts (Infrastructure As A Code) that can be run individually, or integrated to a Jenkins instance to create/update/destroy the infrastructure in a new/existing environment for columbo iResearch project.

### Getting Started

Everytime we create/update scripts to create a new resource or to update an existing one, please make sure to run "terraform fmt" command in order to rewrite config files to canonical format.<br/>
These scripts are created using HCL (HashiCorp Configuration Language) Terraform.<br/>
The scripts are split into modules for each of the service (like lambda, S3, gateway) that will be required/created for the application, and then there are folders for each environment to hold the specific configuration information which can be different between the environments.

### Access Keys

Note that we do not manage access keys using Terraform. Access keys are managed only through CloudOps. A ticket should be created for the CloudOps team to generate an access key for an IAM user and to be handed over.

### Prerequisites

Terraform Executable Binary - [Terraform v0.12.31](https://releases.hashicorp.com/terraform/0.12.31/) <br/>
Terraform Documentation Binary - [terraform-docs](https://github.com/terraform-docs/terraform-docs)  
Terraform Security Binary - [tfsec](https://github.com/liamg/tfsec)  
Checkov Security Binary - [checkov](https://github.com/bridgecrewio/checkov)  
Inspec - [inspec](https://community.chef.io/products/chef-inspec/)

#### Initialize:
terraform init --reconfigure<br/>
##### Requires input key:
irsch/<font color='red'>INPUT_ENV</font>/terraform.tfstate

#### Plan:
terraform plan -var env=<font color='red'>INPUT_ENV</font>

#### Apply:
terraform apply -var env=<font color='red'>INPUT_ENV</font>

#### Destroy:
terraform destroy -var env=<font color='red'>INPUT_ENV</font>

### Running the tests

TODO include instructions of integration tests we are planning to add

### INPUT_ENV can be the following:

| Folders | DEV | QA | PROD | DR | STG |
|------|-------------|------|---------|:--------:|:--------:|
| Eligible Environments | dev2, dev3 | q1, q1a, q2, q2a | pd | dr | stg |

**Dev3 is a hotfix environment, and the updates to it should be made from master branch (production copy of scripts)

### Deployment
Currently the scripts are run by the cloudOPS/Ensono Admin teams manually. using the above steps.

### Authors:
Gopinath Mulumudi<br/>
John Losito

### License
This project is the property of Dun and Bradstreet.
