variable "regions_abbrev_map" {
  type = map(any)
  default = {
    "eu-west-1"      = "euw1"
    "eu-west-2"      = "euw2"
    "eu-west-3"      = "euw3"
    "eu-north-1"     = "eun1"
    "eu-central-1"   = "euc1"
    "us-east-1"      = "use1"
    "us-east-2"      = "use2"
    "us-west-1"      = "usw1"
    "us-west-2"      = "usw2"
    "ca-central-1"   = "cac1"
    "ap-south-1"     = "aps1"
    "ap-southeast-1" = "apse1"
    "ap-southeast-2" = "apse2"
    "ap-northeast-1" = "apne1"
    "ap-northeast-2" = "apne2"
    "ap-northeast-3" = "apne3"
    "sa-east-1"      = "sae1"
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/8"
}

variable "instance_type" {
  type    = string
  default = "m5.large"
}

variable "spec_file" {
  type    = string
  default = "tests/default.yaml"
}

variable "node_exporter_enabled_collectors" {
  type    = list(string)
  default = ["buddyinfo", "cpu", "diskstats", "ethtool", "filefd", "filesystem", "loadavg", "meminfo", "netdev", "netstat", "processes", "sockstat", "stat", "systemd", "tcpstat", "time", "uname", "vmstat"]
}

variable "deb_architecture_map" {
  type = map(any)
  default = {
    "armv6l" : "armhf",
    "armv7l" : "armhf",
    "aarch64" : "arm64",
    "x86_64" : "amd64",
    "i386" : "i386"
  }
}
