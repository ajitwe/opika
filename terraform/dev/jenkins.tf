# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Creating a New Key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  filename        = "/Users/ajitsingh/${local.name}.pem"
  content         = tls_private_key.key.private_key_pem
  file_permission = "0400"

  # Ignore any future changes to this resource
  lifecycle {
    ignore_changes = all
  }
}

module "ops_key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "1.0.1"

  key_name   = local.name
  public_key = tls_private_key.key.public_key_openssh
}

# Security Group for Jenkins (allow HTTP and SSH)
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow HTTP and SSH for Jenkins"
  vpc_id      = module.vpc.vpc_id # Make sure this references the VPC of your EKS cluster

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance for Jenkins
resource "aws_instance" "jenkins_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnets[0] # Public subnet from your VPC module
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  key_name = module.ops_key_pair.key_pair_key_name

  # Associate a public IP address with the instance
  associate_public_ip_address = true

  # Jenkins installation using User Data
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install java-openjdk11 -y
              wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              yum install jenkins git docker unzip curl -y
              systemctl start jenkins
              systemctl enable jenkins
              systemctl start docker
              systemctl enable docker
              usermod -aG docker jenkins
              curl -LO https://releases.hashicorp.com/terraform/1.5.6/terraform_1.5.6_linux_amd64.zip
              unzip terraform_1.5.6_linux_amd64.zip
              mv terraform /usr/local/sbin/
              chown jenkins:jenkins /usr/local/sbin/terraform
              EOF

  tags = {
    Name = "Jenkins"
  }

  # Add an EBS volume
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Adding a secondary EBS volume
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = 20
    volume_type = "gp3"
  }
}

# Output Jenkins instance public IP for convenience
output "jenkins_public_ip" {
  value = aws_instance.jenkins_instance.public_ip
}