resource "aws_cloudwatch_event_rule" "ecr" {
  name          = "${var.app_full}-ECR-update"
  description   = "${var.app_full}-ECR-update"
  event_pattern = <<-JSON
  {
    "source": [
      "aws.ecr"
    ],
    "detail-type": [
      "ECR Image Action"
    ],
    "detail": {
        "action-type": [
          "PUSH"
        ],
        "image-tag": [
          "latest"
        ],
        "repository-name": [
          ${jsonencode(var.cloudwatch_event_ecr_repository_name)}
        ],
        "result": [
          "SUCCESS"
        ]
    }
  }
  JSON

}

resource "aws_cloudwatch_event_target" "ecr" {
  rule      = aws_cloudwatch_event_rule.ecr.name
  target_id = aws_cloudwatch_event_rule.ecr.name
  arn       = aws_codepipeline.this.arn
  role_arn  = var.cloudwatch_event_events_role_arn
}
