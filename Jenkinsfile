pipeline {
	agent any
	options{
		ansiColor('xterm')
	}
	tools{
     		terraform 'terraform-11'
	}
    stages {
	    stage('env'){
		    steps{
		    	sh "printenv"
		    }
	    }
            	stage('Terraform init') {
			steps {
				sh "terraform init"
			}
	    }
		stage('Terraform plan') {
			steps {
				
				withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'awsCredentials', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
					sh "terraform plan -var 'aws_access_key=$AWS_ACCESS_KEY_ID' -var 'aws_secret_key=$AWS_SECRET_ACCESS_KEY' -var 'jenkins_url=$JENKINS_URL' -out eShop.tfplan"
				}
			}
		}
	    
		stage('Terraform apply') {
			steps {
					withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'awsCredentials', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
					sh "terraform apply -var 'aws_access_key=$AWS_ACCESS_KEY_ID' -var 'aws_secret_key=$AWS_SECRET_ACCESS_KEY' -var 'jenkins_url=$JENKINS_URL' --auto-approve"
				}
			}
		}
	}
	post {
		always {
			cleanWs deleteDirs: true, notFailBuild: true
		}
	}
}
