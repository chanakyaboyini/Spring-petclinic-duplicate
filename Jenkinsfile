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
          sh '''
            echo "Waiting up to 10 minutes for Nexus at http://${NEXUS_HOST}/service/rest/v1/status …"
            for i in {1..20}; do
              STATUS=$(curl -u $NEXUS_USR:$NEXUS_PSW -s -o /dev/null -w "%{http_code}" \
                       http://$NEXUS_HOST/service/rest/v1/status || echo "000")
              echo "→ HTTP $STATUS"
              if [ "$STATUS" -eq 200 ]; then
                echo "✓ Nexus is up!"
                exit 0
              fi
              echo "…attempt $i not ready, sleeping 30s."
              sleep 30
            done
            echo "✗ Nexus did not respond after 10 minutes."
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

    stage('Convert JAR to WAR') {
      steps {
        unstash 'app-jar'
        script {
          def jarPath  = findFiles(glob: 'target/*.jar')[0].path
          def jarName  = jarPath.tokenize('/').last()
          def baseName = jarName.replace('.jar','')
          env.JAR_PATH = jarPath
          env.JAR_NAME = jarName
          env.WAR_NAME = "${baseName}.war"
        }
        sh '''
          rm -rf war_staging ${WAR_NAME}
          mkdir -p war_staging/WEB-INF/lib war_staging/WEB-INF/classes

          cp ${JAR_PATH} war_staging/WEB-INF/lib/
          unzip -q war_staging/WEB-INF/lib/${JAR_NAME} \
                -d war_staging/WEB-INF/classes

          cd war_staging
          jar cf ../${WAR_NAME} .
        '''
        archiveArtifacts artifacts: "${WAR_NAME}", fingerprint: true
        stash includes: "${WAR_NAME}", name: 'app-war'
        echo "Converted ${JAR_NAME} to ${WAR_NAME}"
      }
    }

    stage('Deploy to Nexus') {
      steps {
        unstash 'app-war'
        script {
          def warPath = findFiles(glob: '*.war')[0].path
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
              file       : warPath,
              type       : 'war'
            ]]
          )
        }
      }
    }
  }

  post {
    success { echo '✅ Pipeline completed and WAR deployed.' }
    failure { echo '❌ Pipeline failed – check the logs above.' }
  }
}