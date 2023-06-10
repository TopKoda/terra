# variables.tf
variable "region" {
  description = "Region to deploy resources into"
  default     = "eu-west-2"
}

variable "instance_type" {
  description = "Type of instance"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default     = "ami-03195679f849f5cee" # This is an AWS Linux 2 AMI for our preferred region
}

variable "key_name" {
  description = "Name of an existing AWS key pair"
  type        = string
  default     = "LUITProject5KeyPair"
}
