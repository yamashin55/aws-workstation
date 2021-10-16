resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

provider "aws" {
  region = "us-east-1"
}

module "jumphost" {
  source        = "./workstation"
  coderAccountPassword = random_password.password.result
  projectPrefix = "PrefixName"
  resourceOwner = "OwnerName"
  vpc           = "vpc-aaaaaaaaaaaaa"
  keyName       = "instance key name"
  mgmtSubnet    = "subnet-aaaaaaaaaaaa"
  securityGroup = "sg-aaaaaaaaaaaaa"
}