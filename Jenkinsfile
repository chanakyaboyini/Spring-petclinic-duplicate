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
  }

  stages {
    stage('Start Nexus EC2') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: env.AWS_CREDENTIALS,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
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
          credentialsId: env.AWS_CREDENTIALS,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          script {
            def ip = sh(
              script: """\
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
        withCredentials([usernamePassword(
          credentialsId: 'nexus-deployer',
          usernameVariable: 'NEXUS_USR',
          passwordVariable: 'NEXUS_PSW'
        )]) {
          script {
            timeout(time: 10, unit: 'MINUTES') {
              waitUntil {
                echo "Checking Nexus at http://${env.NEXUS_HOST}/service/rest/v1/status"
                def status = sh(
                  script: "curl -u ${NEXUS_USR}:${NEXUS_PSW} -s -o /dev/null -w '%{http_code}' http://${env.NEXUS_HOST}/service/rest/v1/status",
                  returnStdout: true
                ).trim()
                echo "→ HTTP ${status}"
                return (status == '200')
              }
            }
          }
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