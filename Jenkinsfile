pipeline {
  agent any

  tools {
    maven 'maven3'
  }

  environment {
    // your Nexus deploy credentials
    NEXUS_CRED         = credentials('nexus-deployer')
    // AWS settings
    AWS_REGION         = 'us-east-1'
    AWS_CREDENTIALS    = 'jenkins-aws-start-stop'               // AWS creds ID in Jenkins
    // Nexus EC2 details
    NEXUS_INSTANCE_ID  = 'i-07e528bbf536acdcd'
    NEXUS_PORT         = '8081'
  }

  stages {
    stage('Start Nexus EC2') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: AWS_CREDENTIALS
        ]]) {
          sh '''
            aws ec2 start-instances \
              --instance-ids ${NEXUS_INSTANCE_ID} \
              --region ${AWS_REGION}

            aws ec2 wait instance-running \
              --instance-ids ${NEXUS_INSTANCE_ID} \
              --region ${AWS_REGION}
          '''
        }
      }
    }

    stage('Fetch Nexus Host') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: AWS_CREDENTIALS
        ]]) {
          script {
            def ip = sh(
              script: """
                aws ec2 describe-instances \
                  --instance-ids ${env.NEXUS_INSTANCE_ID} \
                  --region ${env.AWS_REGION} \
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
        // reuse same Nexus credentials to hit the status endpoint
        withCredentials([usernamePassword(
          credentialsId: 'nexus-deployer',
          usernameVariable: 'NEXUS_USR',
          passwordVariable: 'NEXUS_PSW'
        )]) {
          sh '''
            echo "Waiting up to 5 minutes for Nexus to respond on port ${NEXUS_PORT}…"
            for i in {1..30}; do
              # -s = silent, -f = fail on HTTP>=400
              if curl -u $NEXUS_USR:$NEXUS_PSW -sf http://$NEXUS_HOST/service/rest/v1/status; then
                echo "✓ Nexus is up!"
                exit 0
              fi
              echo "…not ready yet (attempt $i). Retrying in 10s."
              sleep 10
            done
            echo "✗ Nexus did not respond in time."
            exit 1
          '''
        }
      }
    }

    stage('Build & Package') {
      steps {
        sh 'mvn clean package -DskipTests -Dcheckstyle.skip=true'
        stash includes: 'target/*.jar', name: 'app-jar'
      }
    }

    stage('Deploy to Nexus') {
      steps {
        unstash 'app-jar'
        script {
          def jarPath = findFiles(glob: 'target/*.jar')[0].path
          nexusArtifactUploader(
            nexusVersion       : 'nexus3',
            protocol           : 'http',
            nexusUrl           : env.NEXUS_HOST,
            credentialsId      : 'nexus-deployer',
            groupId            : 'org.springframework.samples',
            version            : '3.1.1',
            repository         : 'Spring-Clinic',
            snapshotRepository : 'Spring-Clinic-snapshots',
            artifacts          : [[
              artifactId : 'spring-clinic',
              classifier : '',
              file       : jarPath,
              type       : 'jar'
            ]]
          )
        }
      }
    }
  }

  post {
    success { echo '✅ Pipeline completed and artifact deployed.' }
    failure { echo '❌ Pipeline failed – check the logs above.' }
  }
}