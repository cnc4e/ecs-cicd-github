terraform {
  required_version = ">= 0.14.7"
}

provider "aws" {
  region = "REGION"
}

# inport network value
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket         = "PJ-NAME-tfstate"
    key            = "network/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "PJ-NAME-tfstate-lock"
    region         = "REGION"
  }
}

data "terraform_remote_state" "preparation" {
  backend = "s3"

  config = {
    bucket         = "PJ-NAME-tfstate"
    key            = "APP-NAME-preparation/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "PJ-NAME-tfstate-lock"
    region         = "REGION"
  }
}

# common parameter settings
locals {
  pj                 = "PJ-NAME"
  app                = "APP-NAME"
  app_full           = "${local.pj}-${local.app}"
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  service_sg_id      = data.terraform_remote_state.preparation.outputs.service_sg_id
  tags = {
    pj    = "PJ-NAME"
    app   = "APP-NAME"
    owner = "OWNER"
  }

  lb_trafic_port       = 80
  lb_traffic_protocol  = "HTTP"
  lb_health_check_path = "/"

  codedeploy_termination_wait_time_in_minutes = 5
}

data "aws_caller_identity" "self" {}
data "aws_region" "current" {}

module "alb" {
  source = "../../../modules/service/service-deploy/alb"

  # common parameter
  app_full = local.app_full
  vpc_id   = local.vpc_id
  tags     = local.tags

  # module parameter
  lb_subnet_ids    = local.public_subnet_ids
  lb_service_sg_id = local.service_sg_id
}

module "service" {
  source = "../../../modules/service/service-deploy/ecs-service-fargate"

  # common parameter
  pj       = local.pj
  app      = local.app
  app_full = local.app_full
  vpc_id   = local.vpc_id
  tags     = local.tags

  # module parameter
  ## task definition
  task_execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.self.account_id}:role/${local.pj}-EcsTaskExecuteRole"

  ## service (dummy)
  service_name              = "${local.app_full}-service"
  service_cluster_arn       = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.self.account_id}:cluster/${local.pj}-cluster"
  service_desired_count     = 1
  service_allow_inbound_sgs = [module.alb.alb_sg_id]
  service_subnets           = local.private_subnet_ids
  service_container_name    = "dummy"
  service_container_port    = 80
  service_sg_id             = local.service_sg_id

  ## ELB Listener & targetgroup
  elb_arn                       = module.alb.alb_arn
  elb_prod_traffic_port         = local.lb_trafic_port
  elb_prod_traffic_protocol     = local.lb_traffic_protocol
  elb_backend_port              = local.lb_trafic_port
  elb_backend_protocol          = local.lb_traffic_protocol
  elb_backend_health_check_path = local.lb_health_check_path

  ## CloudWatch Logs
  clowdwatch_log_groups = ["/${local.pj}-cluster/${local.app_full}-service"]

  depends_on = [module.alb]

}
