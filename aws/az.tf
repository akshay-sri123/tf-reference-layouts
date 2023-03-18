output "zones" {
  value = split(",", lookup(null_resource.zones.triggers, "names"))
}

data "aws_availability_zones" "available" {}

variable "max_az" {
  default = "1"
  type    = number
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

## Return a subset of availability zones based on var.max_az and region
resource "null_resource" "zones" {
  triggers = {
    names = join(",", slice(data.aws_availability_zones.available.names, 0, min(var.max_az, length(data.aws_availability_zones.available.names))))
  }
}

resource "null_resource" "zone_count" {
  triggers = {
    total = length(split(",", lookup(null_resource.zones.triggers, "names")))
  }
}

resource "null_resource" "multiplier" {
  triggers = {
    value = max((1 % lookup(null_resource.zone_count.triggers, "total")) * var.max_az, 1)
  }
}


