pipeline {
  agent any

  tools {
    maven 'maven3'
  }

  environment {
    AWS_REGION         = 'us-east-1'
    AWS_CREDENTIALS    = 'jenkins-aws-start-stop'
    NEXUS_INSTANCE_ID  = 'i-07e528bbf536acdcd'
    NEXUS_PORT         = '8081'

    AMI_ID             = 'ami-050fd9796aa387c0d'
    INSTANCE_TYPE      = 't2.micro'
    KEY_NAME           = 'newjenkinskey'
    SECURITY_GROUP     = 'sg-0ece4b3e66a57dd4d'
    SUBNET_ID          = 'subnet-0d08241fda0e0aa1f'

    CATALINA_VERSION   = '9.0.82'
    CATALINA_MAJOR     = '9'
    CATALINA_TAR       = "apache-tomcat-${CATALINA_VERSION}.tar.gz"
    CATALINA_DIR       = "apache-tomcat-${CATALINA_VERSION}"
    CATALINA_URL       = "https://archive.apache.org/dist/tomcat/tomcat-${CATALINA_MAJOR}/v${CATALINA_VERSION}/bin/${CATALINA_TAR}"
  }

  stages {
    stage('Launch EC2 Instance') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: AWS_CREDENTIALS,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          script {
            env.INSTANCE_ID = sh(
              script: """
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
              """,
              returnStdout: true
            ).trim()
            echo "Launched EC2 instance: ${env.INSTANCE_ID}"
          }
        }
      }
    }

    stage('Wait for Instance & Get IP') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: AWS_CREDENTIALS,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          script {
            sh "aws ec2 wait instance-running --instance-ids ${env.INSTANCE_ID} --region $AWS_REGION"
            env.PUBLIC_IP = sh(
              script: """
                aws ec2 describe-instances \
                  --instance-ids ${env.INSTANCE_ID} \
                  --region $AWS_REGION \
                  --query 'Reservations[0].Instances[0].PublicIpAddress' \
                  --output text
              """,
              returnStdout: true
            ).trim()
            echo "Instance Public IP: ${env.PUBLIC_IP}"
          }
        }
      }
    }

    stage('Start Nexus EC2') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: AWS_CREDENTIALS,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          sh """
            aws ec2 start-instances \
              --instance-ids ${env.NEXUS_INSTANCE_ID} \
              --region $AWS_REGION

            aws ec2 wait instance-running \
              --instance-ids ${env.NEXUS_INSTANCE_ID} \
              --region $AWS_REGION
          """
        }
      }
    }

    stage('Fetch Nexus Host') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: AWS_CREDENTIALS,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          script {
            def ip = sh(
              script: """
                aws ec2 describe-instances \
                  --instance-ids ${env.NEXUS_INSTANCE_ID} \
                  --region $AWS_REGION \
                  --query 'Reservations[0].Instances[0].PublicIpAddress' \
                  --output text
              """,
              returnStdout: true
            ).trim()
            env.NEXUS_HOST = "${ip}:${env.NEXUS_PORT}"
          }
        }
        echo "Resolved Nexus host: ${env.NEXUS_HOST}"
      }
    }

    stage('Wait for Nexus to Be Ready') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'nexus-deployer',
          usernameVariable: 'NEXUS_USR',
          passwordVariable: 'NEXUS_PSW'
        )]) {
          sh """
            echo "Waiting for Nexus at http://${env.NEXUS_HOST}/service/rest/v1/status"
            for i in {1..20}; do
              STATUS=\$(curl -u \$NEXUS_USR:\$NEXUS_PSW -s -o /dev/null -w "%{http_code}" \
                       http://${env.NEXUS_HOST}/service/rest/v1/status || echo "000")
              echo "→ HTTP \$STATUS"
              if [ "\$STATUS" -eq 200 ]; then
                echo "✓ Nexus is up!"
                exit 0
              fi
              sleep 30
            done
            echo "✗ Nexus did not respond after 10 minutes."
            exit 1
          """
        }
      }
    }

    stage('Build & Package') {
      steps {
        sh 'mvn clean package -DskipTests -Dcheckstyle.skip=true'
        stash includes: 'target/*.jar', name: 'app-jar'
      }
    }

    stage('Convert JAR to WAR') {
      steps {
        unstash 'app-jar'
        script {
          def file = findFiles(glob: 'target/*.jar')[0]
          env.JAR_PATH = file.path
          env.JAR_NAME = file.name
          env.WAR_NAME = file.name.replace('.jar', '.war')
        }
        sh """
          rm -rf war_staging ${env.WAR_NAME}
          mkdir -p war_staging/WEB-INF/lib war_staging/WEB-INF/classes
          cp ${env.JAR_PATH} war_staging/WEB-INF/lib/
          unzip -q war_staging/WEB-INF/lib/${env.JAR_NAME} -d war_staging/WEB-INF/classes
          cd war_staging
          jar cf ../${env.WAR_NAME} .
        """
        archiveArtifacts artifacts: "${env.WAR_NAME}", fingerprint: true
        stash includes: "${env.WAR_NAME}", name: 'app-war'
      }
    }

    stage('Deploy to Nexus') {
      steps {
        unstash 'app-war'
        nexusArtifactUploader(
          nexusVersion  : 'nexus3',
          protocol      : 'http',
          nexusUrl      : env.NEXUS_HOST,
          credentialsId : 'nexus-deployer',
          groupId       : 'org.springframework.samples',
          version       : '3.1.1',
          repository    : 'Spring-Clinic',
          artifacts     : [[
            artifactId: 'spring-clinic',
            file      : findFiles(glob: '*.war')[0].path,
            type      : 'war'
          ]]
        )
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline completed and WAR deployed to Nexus.'
    }
    failure {
      echo '❌ Pipeline failed – check the logs above.'
    }
  }
}