# stage/terragrunt.hcl
remote_state {
  backend  = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "ninjadeer-terragrunt-kiss-url-shortener"

    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

# Indicate what region to deploy the resources into
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-1"
}
EOF
}

terraform {
  source = "../../terraform/aws"
}

