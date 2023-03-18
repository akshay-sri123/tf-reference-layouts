output "bastion_public_ips" {
  value = toset(aws_instance.bastion[*].public_ip)
}

variable "bastion_ami" {
  type = string
  default = "ami-0f2e14a2494a72db9"
}

variable "bastion_flavor" {
  type = string
  default = "t2.nano"
}

variable "bastion_allowed_origins" {
  type = string
  default = "0.0.0.0/0"
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
}

resource "aws_key_pair" "bastion" {
  key_name      = "bastion"
  public_key    = tls_private_key.bastion.public_key_openssh
}

resource "aws_security_group" "bastion" {
  name                = "bastion-sg"
  description         = "SG rule for bastion"
  vpc_id              = aws_vpc.vpc.id

  egress {
    cidr_blocks   = [var.bastion_allowed_origins]
    from_port     = 0
    protocol      = -1
    to_port       = 0
  }

  ingress {
    cidr_blocks    = [var.bastion_allowed_origins]
    from_port     = 22
    protocol      = "tcp"
    to_port       = 22
  }

  revoke_rules_on_delete = true
}

resource "aws_instance" "bastion" {
  count                             = lookup(null_resource.zone_count.triggers, "total")
  ami                               = var.bastion_ami
  associate_public_ip_address       = true
  instance_type                     = var.bastion_flavor
  key_name                          = aws_key_pair.bastion.key_name
  subnet_id                         = element(aws_subnet.public.*.id, count.index)
  vpc_security_group_ids            = ["${aws_security_group.bastion.id}"]
}