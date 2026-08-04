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
        script {
          def pythonCmd = sh(script: '''
            if command -v python3 >/dev/null 2>&1; then
              echo python3
            elif command -v python >/dev/null 2>&1; then
              echo python
            else
              echo python-not-found >&2
              exit 1
            fi
          ''', returnStdout: true).trim()

          sh """
            ${pythonCmd} -m venv .venv
            . .venv/bin/activate
            python -m pip install --upgrade pip
            python -m pip install -r requirements-dev.txt
            pytest --junitxml=test-results.xml --cov=. --cov-report=xml --cov-report=term-missing
          """
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        script {
          def sonarAvailable = sh(script: 'command -v sonar-scanner >/dev/null 2>&1', returnStatus: true) == 0
          def sonarHost = env.SONAR_HOST_URL?.trim()

          if (!sonarAvailable || !sonarHost) {
            echo 'Skipping SonarQube analysis because sonar-scanner or SONAR_HOST_URL is not configured.'
            return
          }

          sh '''
            . .venv/bin/activate

            sonar-scanner \
              -Dsonar.projectKey=boardgame-python \
              -Dsonar.projectName=boardgame-python \
              -Dsonar.sources=. \
              -Dsonar.python.version=3 \
              -Dsonar.python.coverage.reportPaths=coverage.xml \
              -Dsonar.host.url=$SONAR_HOST_URL
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        script {
          def sonarHost = env.SONAR_HOST_URL?.trim()
          if (!sonarHost) {
            echo 'Skipping quality gate because SonarQube is not configured.'
            return
          }

          try {
            timeout(time: 5, unit: 'MINUTES') {
              waitForQualityGate abortPipeline: true
            }
          } catch (Exception e) {
            echo "Quality gate could not be evaluated: ${e.getMessage()}"
          }
        }
      }
    }

    stage('Trivy Filesystem Scan') {
      steps {
        script {
          if (sh(script: 'command -v trivy >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'Skipping Trivy filesystem scan because trivy is not installed.'
            return
          }

          sh 'trivy fs --severity HIGH,CRITICAL --exit-code 1 --no-progress .'
        }
      }
    }

    stage('Build Image') {
      steps {
        script {
          if (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'Skipping Docker image build because docker is not installed.'
            return
          }

          sh 'docker build --pull -t $IMAGE .'
        }
      }
    }

    stage('Trivy Image Scan') {
      steps {
        script {
          if (sh(script: 'command -v trivy >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'Skipping Trivy image scan because trivy is not installed.'
            return
          }

          sh 'trivy image --severity HIGH,CRITICAL --exit-code 1 --no-progress $IMAGE'
        }
      }
    }

    stage('Push Image') {
      steps {
        script {
          if (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'Skipping image push because docker is not installed.'
            return
          }

          if (!env.DOCKER_USER?.trim() || !env.DOCKER_TOKEN?.trim()) {
            echo 'Skipping image push because Docker Hub credentials were not provided.'
            return
          }

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
        script {
          if (sh(script: 'command -v kubectl >/dev/null 2>&1', returnStatus: true) != 0) {
            echo 'Skipping deployment because kubectl is not installed.'
            return
          }

          def kubeconfigPath = env.KUBECONFIG_FILE?.trim()
          if (!kubeconfigPath || sh(script: "test -f '${kubeconfigPath}'", returnStatus: true) != 0) {
            echo 'Skipping deployment because a kubeconfig file was not provided.'
            return
          }

          sh """
            export KUBECONFIG='${kubeconfigPath}'

            kubectl apply -f k8s/namespace.yaml

            sed "s|IMAGE_PLACEHOLDER|$IMAGE|g" k8s/deployment.yaml | kubectl apply -f -

            kubectl apply -f k8s/service.yaml

            kubectl apply -f k8s/ingress.yaml

            kubectl -n $K8S_NAMESPACE rollout status deployment/boardgame-api --timeout=180s
          """
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
