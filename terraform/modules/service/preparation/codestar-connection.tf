resource "aws_codestarconnections_connection" "github" {
  name          = "github"
  provider_type = "GitHub"
}
