pipeline {
	agent any
	options{
		ansiColor('xterm')
	}
	tools{
     		terraform 'terraform-11'
	}
    stages {
	    
	    	stage('Copy Artifacts'){
		    	steps{
		    		copyArtifacts filter: 'terraform.tfstate', fingerprintArtifacts: true, projectName: 'eShopOnWebInfrastructure', selector: lastSuccessful(), optional: true	
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
					sh "terraform plan -var 'aws_access_key=$AWS_ACCESS_KEY_ID' -var 'aws_secret_key=$AWS_SECRET_ACCESS_KEY' -var 'jenkins_url=$JENKINS_URL' -var 'master_pswd=$MASTER_PASSWORD' -var 'master_name=$MASTER_USERNAME' -out eShop.tfplan"
				}
			}
		}
	    
		stage('Terraform apply') {
			steps {
					withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'awsCredentials', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
					sh "terraform apply -var 'aws_access_key=$AWS_ACCESS_KEY_ID' -var 'aws_secret_key=$AWS_SECRET_ACCESS_KEY' -var 'jenkins_url=$JENKINS_URL' -var 'master_pswd=$MASTER_PASSWORD' -var 'master_name=$MASTER_USERNAME'  --auto-approve"
				}
			}
		}
	    stage('Archive')
	    steps{
	    		    	archiveArtifacts artifacts: 'terraform.tfstate', followSymlinks: false	
	    }
	}
	post {

		always {
			cleanWs deleteDirs: true, notFailBuild: true
		}
	}
}
