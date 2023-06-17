terraform {
  # Note: can't use variables in the terraform block.
  # S3 bucket must already exist too.
  backend "s3" {
    bucket = "jmac-wk21-state-file-store"
    key    = "projects/states/terraform.tfstate"
    region = "eu-west-3"
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_1
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_1
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_2
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_2
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_1
  availability_zone = var.availability_zone_1
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_2
  availability_zone = var.availability_zone_2
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# Associate the private subnets with the private route table
resource "aws_route_table_association" "private_route_table_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Get the latest AWS Linux 2 image
data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }
  owners = ["137112412989"] # Amazon
}

resource "aws_launch_configuration" "asg_config" {
  name                        = "terraform-asg-example"
  image_id                    = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.asg_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
                AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                REGION=$${AVAILABILITY_ZONE::-1}
                echo "<h1>LUIT Week21 - Johnny Mac - June 2023</h1>" | sudo tee /var/www/html/index.html
                echo "<p>Instance ID: $INSTANCE_ID</p>" | sudo tee -a /var/www/html/index.html
                echo "<p>Region: $REGION</p>" | sudo tee -a /var/www/html/index.html
                echo "<p>Availability Zone: $AVAILABILITY_ZONE</p>" | sudo tee -a /var/www/html/index.html
                sudo systemctl restart httpd
                EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Launch the ALB in the public subnets
resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  # enable_deletion_protection = true
}

resource "aws_lb_target_group" "example" {
  name     = "example"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/"
    port                = "traffic-port"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

# Launch the ASG in the private subnets
resource "aws_autoscaling_group" "asg" {
  desired_capacity     = var.desired_capacity
  launch_configuration = aws_launch_configuration.asg_config.name
  max_size             = var.max_size
  min_size             = var.min_size
  vpc_zone_identifier  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  # Associate ASG with ALB Target Group
  target_group_arns = [aws_lb_target_group.example.arn]

  tag {
    key                 = "Name"
    value               = "ASG Instances"
    propagate_at_launch = true
  }
}

# Create a Security Group for the ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow inbound traffic from anywhere on port 80 and 443"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb_sg"
  }
}

# Create a Security Group for instances in the ASG
resource "aws_security_group" "asg_sg" {
  name        = "asg_sg"
  description = "Allow inbound traffic on port 80 from the ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "asg_sg"
  }
}
