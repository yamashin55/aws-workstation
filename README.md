# aws-create-workstation

## Usage 

git clone https://.......

vi main.tf

```bash
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
```
 
terraform init

terraform apply

![](./images/02.png)

Code-Server listening.

URL:  http://<IPADDRESS>:8080
PASS: 
![](./images/01.png)
