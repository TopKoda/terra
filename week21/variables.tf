variable "region" {
  description = "The region to create resources in"
  default     = "eu-west-3"
}

variable "availability_zone_1" {
  description = "Availability Zone 1 for our region"
  default     = "eu-west-3a"
}

variable "availability_zone_2" {
  description = "Availability Zone 2 for our region"
  default     = "eu-west-3b"
}

variable "bucket_name" {
  description = "The name of the S3 bucket where the Terraform state file will be stored"
  default     = "jmac-wk21-state-file-store"
}

variable "instance_type" {
  description = "The type of instance to start"
  default     = "t2.micro"
}

variable "min_size" {
  description = "The minimum size of the auto scaling group"
  default     = 2
}

variable "max_size" {
  description = "The maximum size of the auto scaling group"
  default     = 5
}

variable "desired_capacity" {
  description = "The desired size of the auto scaling group"
  default     = 2
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_1" {
  description = "The CIDR block for public subnet 1 of 2"
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_2" {
  description = "The CIDR block for public subnet 2 of 2"
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_1" {
  description = "The CIDR block for private subnet 1 of 2"
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr_2" {
  description = "The CIDR block for private subnet 2 of 2"
  default     = "10.0.4.0/24"
}

variable "key_path" {
  description = "The path to the key for storing state in the S3 bucket"
  default     = "projects/states/terraform.tfstate"
}

