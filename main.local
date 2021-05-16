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
  projectPrefix = "syamada"
  resourceOwner = "syamada"
  vpc           = "vpc-a3cc17db"
  keyName       = "syamada"
  mgmtSubnet    = "subnet-09857e6044f477e0c"
  securityGroup = "sg-075640dd481103c89"
}
