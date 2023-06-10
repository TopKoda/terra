# main.tf

# IAM policy that allows read/write access to S3
resource "aws_iam_policy" "s3_access" {
  name        = "S3Access"
  description = "Allows read/write access to S3"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::*",
            "Effect": "Allow"
        }
    ]
  }
EOF
}

# IAM role for EC2
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "EC2S3AccessRole"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
EOF
}

# Attaching IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Instance profile that we will assign to our EC2 instance
resource "aws_iam_instance_profile" "instance_profile" {
  name = "jenkins_instance_profile"
  role = aws_iam_role.ec2_s3_access_role.name
}

# EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  # This will run a script to install and start Jenkins
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install -y java-openjdk11
    sudo yum install -y wget
    sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io-2023.key
    sudo yum install jenkins -y
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
  EOF

  tags = {
    Name = "my-jenkins-server"
  }
}

# Security Group
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allow inbound traffic on port 22 and 8080 and outbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # My IP CIDR
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # My IP CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 bucket for Jenkins artifacts
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "johnnymac-luit-week20-jenkins-artifacts"
}

resource "aws_s3_bucket_public_access_block" "jenkins_artifacts_acl" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  block_public_acls   = true
  block_public_policy = true
}
