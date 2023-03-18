output "nlb" {
  value = "${aws_lb.nlb.dns_name}"
}

/*
NLB includes components like LoadBalancer, Listeners and Target Groups.
LoadBalancer which distributes traffic across multiple targets (EC2 instances, IPs, Lambda etc)
Listener is a process that checks for connection requests using the configured port and protocol, and forwards to a target group.
Target Groups are used to route requests to one or more registered targets, also implements health checks on targets.
*/

## Target Groups for both 80 (HTTP) and 443 (HTTPS)
resource "aws_lb_target_group" "nlb-443" {
  name        = "bootcamp-nlb-443"
  port        = 443
  protocol    = "TCP"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_lb_target_group" "nlb-80" {
  name        = "bootcamp-nlb-80"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.vpc.id
}

## Register EC2 instances under a defined Target Group
## so that requests can be received by the targets on the configured port
resource "aws_lb_target_group_attachment" "nlb-443" {
  count             = lookup(null_resource.multiplier.triggers, "value") * var.worknode_count_per_az
  port              = 443
  target_group_arn  = aws_lb_target_group.nlb-443.arn
  target_id         = element(aws_instance.worknode.*.id, count.index)
}

resource "aws_lb_target_group_attachment" "nlb-80" {
  count             = lookup(null_resource.multiplier.triggers, "value") * var.worknode_count_per_az
  port              = 80
  target_group_arn  = aws_lb_target_group.nlb-80.arn
  target_id         = element(aws_instance.worknode.*.id, count.index)
}

## Configure listeners for both 80 (HTTP) and 443 (HTTPS) to forward traffic to target groups
resource "aws_lb_listener" "nlb-443" {
  default_action {
    target_group_arn  = aws_lb_target_group.nlb-443.arn
    type              = "forward"
  }

  load_balancer_arn   = aws_lb.nlb.arn
  port                = "443"
  protocol            = "TCP"
}

resource "aws_lb_listener" "nlb-80" {
  default_action {
    target_group_arn  = aws_lb_target_group.nlb-80.arn
    type              = "forward"
  }

  load_balancer_arn   = aws_lb.nlb.arn
  port                = "80"
  protocol            = "TCP"
}

## The NLB configuration will include a mapping between the public subnets and EIPs.
## Creating a local variable to store the created public subnet IDs which will then act as indices for the EIP
locals {
  # public_subnet_ids = toset(aws_subnet.public[*].id)
  public_subnet_ids = {for idx, val in aws_subnet.public[*].id: idx => val}
}

## Creating one EIP for each public subnet.
resource "aws_eip" "nlb" {
  for_each  = local.public_subnet_ids
  vpc       = true
}

## Create Network LoadBalancer, allocate it an EIP and map the NLB to a subnet, per AZ.
resource "aws_lb" "nlb" {
  internal              = "false"
  load_balancer_type    = "network"
  name                  = "bootcamp-nlb"

  dynamic "subnet_mapping" {
    for_each = local.public_subnet_ids

    content {
      subnet_id     = subnet_mapping.value
      allocation_id = aws_eip.nlb[subnet_mapping.value].id
    }
  }
}