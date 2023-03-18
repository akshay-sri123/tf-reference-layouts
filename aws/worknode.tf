output "worknode_private_ips" {
  value = toset(aws_instance.worknode[*].private_ip)
}

variable "worknode_count_per_az" {
  type    = number
  default = 1
}

variable "worknode_ami" {
  type    = string
  default = "ami-0f2e14a2494a72db9"
}

variable "worknode_disk_size" {
  type    = number
  default = 20
}

variable "worknode_flavor" {
  type    = string
  default = "t2.nano"
}

resource "tls_private_key" "worknode" {
  algorithm = "RSA"
}

resource "aws_key_pair" "worknode" {
  key_name      = "worknode"
  public_key    = tls_private_key.worknode.public_key_openssh
}

##
resource "aws_security_group" "worknode" {
  name                = "worknode-sg"
  description         = "SG rule for worknode nodes"
  vpc_id              = aws_vpc.vpc.id

  egress {
    cidr_blocks   = ["0.0.0.0/0"]
    from_port     = 0
    protocol      = -1
    to_port       = 0
  }

  ingress {
    cidr_blocks    = ["0.0.0.0/0"]
    from_port     = 0
    protocol      = -1
    to_port       = 0
  }

  revoke_rules_on_delete = true
}

resource "aws_instance" "worknode" {
  count                             = lookup(null_resource.multiplier.triggers, "value") * var.worknode_count_per_az
  ami                               = var.worknode_ami
  associate_public_ip_address       = false
  instance_type                     = var.worknode_flavor
  key_name                          = aws_key_pair.worknode.key_name
  subnet_id                         = element(aws_subnet.private.*.id, count.index % lookup(null_resource.zone_count.triggers, "total"))
  vpc_security_group_ids            = ["${aws_security_group.worknode.id}"]
}

resource "aws_ebs_volume" "worknode" {
  count               = lookup(null_resource.multiplier.triggers, "value") * var.worknode_count_per_az
  availability_zone   = element(aws_instance.worknode.*.availability_zone, count.index)
  size                = var.worknode_disk_size
}

resource "aws_volume_attachment" "worknode" {
  count         = lookup(null_resource.multiplier.triggers, "value") * var.worknode_count_per_az
  device_name   = "/dev/sdh"
  force_detach  = false
  volume_id     = element(aws_ebs_volume.worknode.*.id, count.index)
  instance_id   = element(aws_instance.worknode.*.id, count.index)
}