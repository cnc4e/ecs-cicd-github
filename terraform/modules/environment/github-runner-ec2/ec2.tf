locals {
  default_init_script = <<SHELLSCRIPT
#!/bin/bash

## install Docker
amazon-linux-extras install docker
systemctl enable docker
systemctl start docker

usermod -a -G docker ec2-user

# Download runner
mkdir actions-runner && cd actions-runner
curl -O -L "https://github.com/actions/runner/releases/download/v${var.ec2_runner_version}/actions-runner-linux-x64-${var.ec2_runner_version}.tar.gz"
tar xzf "./actions-runner-linux-x64-${var.ec2_runner_version}.tar.gz"

# setup runner
chmod 777 -R /actions-runner
su - ec2-user -c '/actions-runner/config.sh --url ${var.ec2_github_url} --token ${var.ec2_registration_token} --name ${var.ec2_runner_name} --work _work --labels ${join(",", var.ec2_runner_tags)}'
su - ec2-user -c '/actions-runner/run.sh'
/actions-runner/svc.sh install
/actions-runner/svc.sh start

## Docker resources prune
echo '
[Unit]
Description=GitHub Runner Docker Executor cleanup task

[Service]
Type=simple
ExecStart=/usr/bin/docker system prune --force
User=ec2-user
' > /etc/systemd/system/github-runner-docker-executor-cleanup.service

echo '
[Unit]
Description=GitHub Runner Docker Executor cleanup task timer

[Timer]
OnCalendar=*-*-* *:00:00
Unit=github-runner-docker-executor-cleanup.service

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/github-runner-docker-executor-cleanup.timer

systemctl enable github-runner-docker-executor-cleanup.timer
systemctl start github-runner-docker-executor-cleanup.timer


    SHELLSCRIPT
}

data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "github_runner" {
  ami                         = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type               = var.ec2_instance_type
  iam_instance_profile        = aws_iam_instance_profile.github_runner.name
  associate_public_ip_address = true
  subnet_id                   = var.ec2_subnet_id
  user_data                   = local.default_init_script

  tags = merge(
    {
      "Name" = "${var.pj}-github-runner"
    },
    var.tags
  )

  root_block_device {
    volume_size = var.ec2_root_block_volume_size
  }

  key_name = var.ec2_key_name

  lifecycle {
    ignore_changes = [ami]
  }
}

