pipeline {
	tools{
      terraform 'terraform-11'
	}
    agent any
    stages {
	stage('Create key-pair') {
			steps {
				sh "aws ec2 create-key-pair --key-name eShop --query 'KeyMaterial' --output text > eShop.pem"
			}
	    }
        stage('Terraform init') {
			steps {
				sh "terraform init"
			}
	    }
		stage('Terraform plan') {
			steps {
				sh "terraform plan -out eShop.tfplan"
			}
		}
		stage('Terraform apply') {
			steps {
				sh "terraform apply --auto-approve"
			}
		}
	}
	post {
		always {
			cleanWs deleteDirs: true, notFailBuild: true
		}
	}
}
