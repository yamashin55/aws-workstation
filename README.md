# aws-create-workstation

##usage 

git clone

vi main.tf

```bash
module "jumphost" {
  source        = "./workstation"
  coderAccountPassword = random_password.password.result
  projectPrefix = "PrefixNAME"
  resourceOwner = "OwnerName"
  vpc           = "vpc-aaaaaaaaaaaaa"
  keyName       = "syamada"
  mgmtSubnet    = "subnet-aaaaaaaaaaaa"
  securityGroup = "sg-aaaaaaaaaaaaa"
}
```
 
terraform init

terraform apply
