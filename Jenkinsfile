pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    REGISTRY = 'docker.io'
    IMAGE_REPOSITORY = 'shekhar013/boardgame-devsecops'
    IMAGE_TAG = "${BUILD_NUMBER}"
    IMAGE = "${REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
    K8S_NAMESPACE = 'boardgame'
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install and Test') {
      steps {
        sh '''
        python3 -m venv .venv
        . .venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements-dev.txt
        pytest --junitxml=test-results.xml --cov=. --cov-report=xml --cov-report=term-missing
        '''
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube') {
          sh '''
          . .venv/bin/activate

          sonar-scanner \
            -Dsonar.projectKey=boardgame-python \
            -Dsonar.projectName=boardgame-python \
            -Dsonar.sources=. \
            -Dsonar.python.version=3 \
            -Dsonar.python.coverage.reportPaths=coverage.xml \
            -Dsonar.host.url=http://34.31.26.40/:9000
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Trivy Filesystem Scan') {
      steps {
        sh 'trivy fs --severity HIGH,CRITICAL --exit-code 1 --no-progress .'
      }
    }

    stage('Build Image') {
      steps {
        sh 'docker build --pull -t $IMAGE .'
      }
    }

    stage('Trivy Image Scan') {
      steps {
        sh 'trivy image --severity HIGH,CRITICAL --exit-code 1 --no-progress $IMAGE'
      }
    }

    stage('Push Image') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'dockerhub-credentials',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_TOKEN'
          )
        ]) {
          sh '''
          echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin
          docker push $IMAGE
          '''
        }
      }
    }

    stage('Deploy to GKE') {
      when {
        expression {
          return env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master'
        }
      }

      steps {
        withCredentials([
          file(
            credentialsId: 'gke-kubeconfig',
            variable: 'KUBECONFIG_FILE'
          )
        ]) {

          sh '''
          export KUBECONFIG=$KUBECONFIG_FILE

          kubectl apply -f k8s/namespace.yaml

          sed "s|IMAGE_PLACEHOLDER|$IMAGE|g" k8s/deployment.yaml | kubectl apply -f -

          kubectl apply -f k8s/service.yaml

          kubectl apply -f k8s/ingress.yaml

          kubectl -n $K8S_NAMESPACE rollout status deployment/boardgame-api --timeout=180s
          '''
        }
      }
    }
  }

  post {
    always {
      junit allowEmptyResults: true, testResults: 'test-results.xml'
      cleanWs()
    }

    success {
      echo "Deployment succeeded: ${IMAGE}"
    }

    failure {
      echo 'Pipeline failed. Check the stage logs and scan reports.'
    }
  }
}
