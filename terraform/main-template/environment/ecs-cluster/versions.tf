terraform {
  required_version = ">= 0.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=3.22.0"
    }
  }

  backend "s3" {
    bucket         = "PJ-NAME-tfstate"
    key            = "ecs-cluster/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "PJ-NAME-tfstate-lock"
    region         = "REGION"
  }
}
