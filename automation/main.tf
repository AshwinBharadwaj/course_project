module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# sg
resource "aws_security_group" "sg_bastion_host" {
  name        = "sg_bastion_host"
  description = "bastion host security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol  = "tcp"
    cidr_blocks = ["${chomp(data.http.selfip.body)}/32"]
    from_port = 22
    to_port   = 22
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "ALL"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_bastion_host"
  }
}

data "http" "selfip" {
    url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "alb-sg" {      
  name        = "alb-sg"
  description = "Security group for Public Web SG"
  vpc_id      = module.vpc.vpc_id
  depends_on  = [module.vpc]

  ingress {
    protocol  = "tcp"
    self      = true
    from_port = 80
    to_port   = 80
    cidr_blocks = ["${chomp(data.http.selfip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "private-sg" {
  name        = "private-sg"
  description = "Security group for Public Web SG"
  vpc_id      = module.vpc.vpc_id
  depends_on  = [module.vpc]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    protocol  = "ALL"
    from_port = 0
    to_port   = 0
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "private-sg"
  }
}

resource "aws_ecr_repository" "ashwin-bharadwaj-c4-p1" {
  name                 = "ashwin-bharadwaj-c4-p1"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_role" "ecr_role" {
  name = "ecr_role"
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

  tags = {
    Name = "ecr_role"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_policy_role" {
  role       = aws_iam_role.ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_instance" "bastion" {
  ami                    = "ami-04505e74c0741db8d"
  instance_type          = "t2.micro"
  key_name               = "upgrad_dev"
  vpc_security_group_ids = [aws_security_group.sg_bastion_host.id]
  subnet_id              = module.vpc.public_subnets[0]
  tags = {
    Name = "bastion"
  }
  provisioner "file" {
    source      = "/home/ubuntu/automation/terra/key.pem"
    destination = "/home/ubuntu/key.pem"
  }
  
  user_data = "${file("install_ansible.sh")}"
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname bash",
      "echo [targets] >> /home/ubuntu/inventory",
      "echo ${aws_instance.jenkins.private_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/key.pem >> /home/ubuntu/inventory",
      "echo ${aws_instance.app_host.private_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/key.pem >> /home/ubuntu/inventory",
      "echo [jenkins] >> /home/ubuntu/inventory",
      "echo ${aws_instance.jenkins.private_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/key.pem >> /home/ubuntu/inventory",
      "sudo chmod 400 /home/ubuntu/key.pem"
    ]
  }
  connection {
    agent = false
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/home/ubuntu/automation/terra/key.pem")
    host        = self.public_ip
  }
}

resource "aws_instance" "jenkins" {
  ami                    = "ami-04505e74c0741db8d"
  instance_type          = "t2.micro"
  key_name               = "upgrad_dev"
  vpc_security_group_ids = [aws_security_group.private-sg.id]
  subnet_id              = module.vpc.private_subnets[0]
    tags = {
    Name = "jenkins"
  }  
}
resource "aws_instance" "app_host" {
  ami                    = "ami-04505e74c0741db8d"
  instance_type          = "t2.micro"
  key_name               = "upgrad_dev"
  vpc_security_group_ids = [aws_security_group.private-sg.id]
  subnet_id              = module.vpc.private_subnets[0]
  tags = {
    Name = "app_host"
  }
}