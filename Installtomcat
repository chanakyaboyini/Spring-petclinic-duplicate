pipeline {
    agent any

    environment {
        AWS_REGION     = 'us-east-1'
        AMI_ID         = 'ami-050fd9796aa387c0d'
        INSTANCE_TYPE  = 't2.micro'
        KEY_NAME       = 'newjenkinskey'
        SECURITY_GROUP = 'sg-0ece4b3e66a57dd4d'
        SUBNET_ID      = 'subnet-0d08241fda0e0aa1f'

        // Tomcat download parameters
        CATALINA_VERSION = '9.0.82'
        CATALINA_MAJOR   = '9'
        CATALINA_TAR     = "apache-tomcat-${CATALINA_VERSION}.tar.gz"
        CATALINA_DIR     = "apache-tomcat-${CATALINA_VERSION}"
        CATALINA_URL     = "https://archive.apache.org/dist/tomcat/tomcat-${CATALINA_MAJOR}/v${CATALINA_VERSION}/bin/${CATALINA_TAR}"
    }

    stages {
        stage('Launch EC2 Instance') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'jenkins-aws-start-stop',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    script {
                        env.INSTANCE_ID = sh(
                            script: '''
aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --region $AWS_REGION \
  --query 'Instances[0].InstanceId' \
  --output text
''',
                            returnStdout: true
                        ).trim()
                        echo "Launched EC2 instance: ${env.INSTANCE_ID}"
                    }
                }
            }
        }

        stage('Wait for Instance & Get IP') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'jenkins-aws-start-stop',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    script {
                        sh "aws ec2 wait instance-running --instance-ids ${env.INSTANCE_ID} --region $AWS_REGION"
                        env.PUBLIC_IP = sh(
                            script: '''
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
''',
                            returnStdout: true
                        ).trim()
                        echo "Instance Public IP: ${env.PUBLIC_IP}"
                    }
                }
            }
        }

        stage('Install Tomcat') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'jenkins-ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    script {
                        sh """
chmod 600 \$SSH_KEY

ssh -o StrictHostKeyChecking=no -i \$SSH_KEY \$SSH_USER@${env.PUBLIC_IP} << 'EOF'
  sudo yum update -y
  sudo yum install -y java-1.8.0-openjdk wget tar
  wget -q $CATALINA_URL
  tar xzf $CATALINA_TAR
  sudo mv $CATALINA_DIR /opt/tomcat
  sudo /opt/tomcat/bin/startup.sh
EOF
"""
                    }
                }
                echo "Tomcat ${env.CATALINA_VERSION} installed and started on ${env.PUBLIC_IP}:8080"
            }
        }
    }

    post {
        always {
            echo "Pipeline complete. Remember to terminate ${env.INSTANCE_ID} when you’re done."
        }
    }
}