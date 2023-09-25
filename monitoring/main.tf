resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

locals {
  vpc_id = aws_default_vpc.default.id
  domain_name = "perf-dashboard.${var.route53_zone_name}"
  instance_type = "a1.medium"
  os_version = "22.04"
  os_arch    = "arm64"
  ami_filter = "ubuntu/images/hvm-ssd/ubuntu-*-${local.os_version}-${local.os_arch}-server-*"
}

resource "aws_security_group" "lb_sg" {
  name        = "${var.namespace}-lb-sg"
  description = "Allow traffic on 443 from the internet and all outbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "TCP"
    cidr_blocks      = [aws_default_vpc.default.cidr_block]
  }
}

resource "aws_security_group" "instance_sg" {
  name        = "${var.namespace}-instance-sg"
  description = "Allow all inbound traffic within sg, within VPC, external SSH access and all outbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self             = true
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_default_vpc.default.cidr_block]
  }

  ingress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "TCP"
    security_groups  = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_launch_template" "grafana-lt" {
  name_prefix = "grafana-lt-"
  image_id = data.aws_ami.ubuntu.id
  instance_type = local.instance_type
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    domain_name = local.domain_name
    region = var.region
    s3_bucket_name = var.s3_bucket_name
    prometheus_url = var.prometheus_url
    grafana_admin_password = var.grafana_admin_password
  }))
  iam_instance_profile {
    arn = aws_iam_instance_profile.grafana.arn
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "grafana"
    }
  }
}

resource "aws_autoscaling_group" "grafana-asg" {
  name                 = "grafana-asg"
  desired_capacity     = 1
  max_size             = 1
  min_size             = 1
  health_check_grace_period = 300
  health_check_type    = "EC2"

  launch_template {
    id = aws_launch_template.grafana-lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.grafana.arn]
  vpc_zone_identifier = data.aws_subnets.vpc_subnets.ids
}

resource "aws_lb" "grafana-lb" {
  name                  = "grafana-lb"
  internal              = false
  load_balancer_type    = "application"
  security_groups       = [aws_security_group.lb_sg.id]
  subnets               = data.aws_subnets.vpc_subnets.ids
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.grafana-lb.arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
}

resource "aws_lb_target_group" "grafana" {
  name     = "grafana-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = local.vpc_id
}

resource "aws_route53_record" "lb" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.grafana-lb.dns_name
    zone_id                = aws_lb.grafana-lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "site" {
  domain_name       = local.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validations" {
  count           = length(aws_acm_certificate.site.domain_validation_options)
  zone_id         = data.aws_route53_zone.public.zone_id
  allow_overwrite = true
  name            = element(aws_acm_certificate.site.domain_validation_options.*.resource_record_name, count.index)
  type            = element(aws_acm_certificate.site.domain_validation_options.*.resource_record_type, count.index)
  records         = [element(aws_acm_certificate.site.domain_validation_options.*.resource_record_value, count.index)]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = aws_route53_record.cert_validations.*.fqdn
}

resource "aws_iam_policy" "grafana" {
  name        = "grafana"
  path        = "/"
  description = "Policy to provide permission to EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:List*"
        ],
        "Resource": [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "aps:GetLabels",
          "aps:GetMetricMetadata",
          "aps:GetSeries",
          "aps:QueryMetrics"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "grafana" {
  name = "grafana"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "grafana" {
  name       = "grafana"
  roles      = [aws_iam_role.grafana.name]
  policy_arn = aws_iam_policy.grafana.arn
}

resource "aws_iam_instance_profile" "grafana" {
  name = "grafana"
  role = aws_iam_role.grafana.name
}
