resource "aws_s3_bucket" "artifact_store" {
  bucket        = var.s3_artifact_store_name
  acl           = "private"
  force_destroy = true

  tags = merge(
    {
      "Name" = var.s3_artifact_store_name
    },
    var.tags
  )

}

data "aws_caller_identity" "self" {}
