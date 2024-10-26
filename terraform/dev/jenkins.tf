

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Import the existing SSH key pair
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = file("~/.ssh/my-jenkins-key.pub")  # Path to your SSH public key
}

# Security Group for Jenkins (allow HTTP and SSH)
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow HTTP and SSH for Jenkins"
  vpc_id      = module.vpc.vpc_id  # Make sure this references the VPC of your EKS cluster

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
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnets[0]  # Public subnet from your VPC module
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  key_name = aws_key_pair.jenkins_key.key_name  # Add the SSH key pair

  # Associate a public IP address with the instance
  associate_public_ip_address = true

  # Jenkins installation using User Data
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install java-openjdk11 -y
              wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              yum install jenkins git docker -y
              systemctl start jenkins
              systemctl enable jenkins
              systemctl start docker
              systemctl enable docker
              EOF

  tags = {
    Name = "Jenkins-EC2"
  }

  # Add an EBS volume
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  # Adding a secondary EBS volume
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = 10
    volume_type = "gp2"
  }
}

# Output Jenkins instance public IP for convenience
output "jenkins_public_ip" {
  value = aws_instance.jenkins_instance.public_ip
}
