locals {
  setting_artifacts_name = "settings"
  image_artifacts_name   = "images"
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github"
  provider_type = "GitHub"
}

resource "aws_codepipeline" "this" {
  name     = "${var.app_full}-pipeline"
  role_arn = var.codepipeline_pipeline_role_arn
  tags = merge(
    {
      "Name" = "${var.app_full}-pipeline"
    },
    var.tags
  )

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifact_store.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "github"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = [local.setting_artifacts_name]
      run_order        = 1
      configuration = {
        ConnectionArn    = var.codestar_conection_arn
        FullRepositoryId = var.codestar_github_repository_id
        BranchName       = "master"
      }
    }

    action {
      name             = "ECR"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = [local.image_artifacts_name]
      run_order        = 2
      configuration = {
        RepositoryName = var.codepipeline_ecr_repository_name
        ImageTag       = "latest"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = [local.setting_artifacts_name, local.image_artifacts_name]

      configuration = {
        ApplicationName                = aws_codedeploy_app.this.name
        DeploymentGroupName            = var.codedeploy_deployment_group_name
        TaskDefinitionTemplateArtifact = local.setting_artifacts_name
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = local.setting_artifacts_name
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName             = local.image_artifacts_name
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }

  depends_on = [aws_codedeploy_deployment_group.ecs]
}
