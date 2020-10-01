##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "jenkins_url" {}
variable "master_pswd" {}
variable "master_name" {}
variable "region" {
  default = "us-east-1"
}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}
variable "subnet2_address_space" {
  default = "10.1.1.0/24"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = ["ami-0c94855ba95c71c99"]
  
  }
}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

}

resource "aws_subnet" "subnet1" {
  cidr_block              = var.subnet1_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "subnet2" {
  cidr_block              = var.subnet2_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[1]
}
  
# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rtb.id
}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "nginx_elb_sg"
  vpc_id = aws_vpc.vpc.id

  #Allow HTTP from anywhere
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
    ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Nginx security group 
resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.network_address_space]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.network_address_space]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LOAD BALANCER #
resource "aws_elb" "web" {
  name = "nginx-elb"

  subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups = [aws_security_group.elb-sg.id]
  instances       = [aws_instance.vm1.id, aws_instance.vm2.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# INSTANCES #
resource "aws_instance" "vm1" {
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]
  key_name               = "eShop"
  user_data = <<EOF
#!/bin/bash

set -xe

NODE_NAME=`hostname`
NUM_EXECUTORS=1

yum update -y
yum install -y amazon-linux-extras
amazon-linux-extras install java-openjdk11

# Download CLI jar from the master
curl ${var.jenkins_url}/jnlpJars/jenkins-cli.jar -o ~/jenkins-cli.jar

# Create node according to parameters passed in
cat <<1EOF | java -jar ~/jenkins-cli.jar -auth "${var.master_name}:${var.master_pswd}" -s "${var.jenkins_url}" create-node "$NODE_NAME" |true
<slave>
  <name>$NODE_NAME</name>
  <description></description>
  <remoteFS>/home/jenkins/agent</remoteFS>
  <numExecutors>$NUM_EXECUTORS</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label>TerraformVM</label>
  <nodeProperties/>
  <userId>$USER</userId>
</slave>
1EOF
# Creating the node will fail if it already exists, so |true to suppress the
# error. This probably should check if the node exists first but it should be
# possible to see any startup errors if the node doesn't attach as expected.


# Download slave.jar
curl ${var.jenkins_url}/jnlpJars/slave.jar -o /tmp/slave.jar

# Run jnlp launcher
java -jar /tmp/slave.jar -jnlpUrl ${var.jenkins_url}/computer/$NODE_NAME/slave-agent.jnlp -jnlpCredentials "${var.master_name}:${var.master_pswd}"



EOF

  connection {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = file("/home/sela/eShop.pem")
  }

     provisioner "remote-exec" {
    inline = [
        # Install nginx
        "sudo amazon-linux-extras install -y nginx1.12",
        "sudo service nginx start",
      
        # Install Docker
        "sudo amazon-linux-extras install -y docker",
        "sudo service docker start",
        "sudo usermod -a -G docker ec2-user",

        # Install dotnet
        "sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm",
        "sudo yum install -y dotnet-sdk-3.1",
        "sudo yum install -y aspnetcore-runtime-3.1",
        "dotnet tool install --global dotnet-ef",
      
        # Install SQL
        "sudo curl https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/msprod.repo",      
        "sudo yum remove mssql-tools unixODBC-utf16-devel",
        "sudo yum install -y mssql-tools unixODBC-devel",
        "echo 'export PATH='$PATH:/opt/mssql-tools/bin'' >> ~/.bash_profile",
        "echo 'export PATH='$PATH:/opt/mssql-tools/bin'' >> ~/.bashrc",
        "source ~/.bashrc"

    ]
  }
#   provisioner "remote-exec" {
#     inline = [
#       "sudo amazon-linux-extras install nginx1",
#       "sudo service nginx start",
#     ]
#   }
}

resource "aws_instance" "vm2" {
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]
  key_name               = "eShop"
  user_data = <<EOF
#!/bin/bash

set -xe

NODE_NAME=`hostname`
NUM_EXECUTORS=1

yum update -y
yum install -y amazon-linux-extras
amazon-linux-extras install java-openjdk11

# Download CLI jar from the master
curl ${var.jenkins_url}/jnlpJars/jenkins-cli.jar -o ~/jenkins-cli.jar

# Create node according to parameters passed in
cat <<1EOF | java -jar ~/jenkins-cli.jar -auth "${var.master_name}:${var.master_pswd}" -s "${var.jenkins_url}" create-node "$NODE_NAME" |true
<slave>
  <name>$NODE_NAME</name>
  <description></description>
  <remoteFS>/home/jenkins/agent</remoteFS>
  <numExecutors>$NUM_EXECUTORS</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label>TerraformVM</label>
  <nodeProperties/>
  <userId>$USER</userId>
</slave>
1EOF
# Creating the node will fail if it already exists, so |true to suppress the
# error. This probably should check if the node exists first but it should be
# possible to see any startup errors if the node doesn't attach as expected.


# Download slave.jar
curl ${var.jenkins_url}/jnlpJars/slave.jar -o /tmp/slave.jar

# Run jnlp launcher
java -jar /tmp/slave.jar -jnlpUrl ${var.jenkins_url}/computer/$NODE_NAME/slave-agent.jnlp -jnlpCredentials "${var.master_name}:${var.master_pswd}"


EOF

  connection {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = file("/home/sela/eShop.pem")

  }

   provisioner "remote-exec" {
    inline = [
        # Install nginx
        "sudo amazon-linux-extras install -y nginx1.12",
        "sudo service nginx start",
      
        # Install Docker
        "sudo amazon-linux-extras install -y docker",
        "sudo service docker start",
        "sudo usermod -a -G docker ec2-user",

        # Install dotnet
        "sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm",
        "sudo yum install -y dotnet-sdk-3.1",
        "sudo yum install -y aspnetcore-runtime-3.1",
        "dotnet tool install --global dotnet-ef",
      
        # Install SQL
        "sudo curl https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/msprod.repo",      
        "sudo yum remove mssql-tools unixODBC-utf16-devel",
        "sudo yum install -y mssql-tools unixODBC-devel",
        "echo 'export PATH='$PATH:/opt/mssql-tools/bin'' >> ~/.bash_profile",
        "echo 'export PATH='$PATH:/opt/mssql-tools/bin'' >> ~/.bashrc",
        "source ~/.bashrc"

    ]
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = aws_elb.web.dns_name
}
