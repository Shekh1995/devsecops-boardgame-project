pipeline {

    agent {
        label 'aws-agent'
    }

    environment {
        IMAGE_NAME = 'boardgame-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        FULL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
    }

    options {
        timestamps()
        skipDefaultCheckout(true)
    }

    stages {

        stage('Checkout') {
            steps {
                echo '===== CHECKOUT ====='

                checkout scm

                sh '''
                    echo "Repository:"
                    git remote -v

                    echo "Commit:"
                    git rev-parse --short HEAD

                    echo "Running on:"
                    hostname

                    echo "User:"
                    whoami
                '''
            }
        }

        stage('Install and Test') {
            steps {
                echo '===== INSTALL AND TEST ====='

                sh '''
                    set -e

                    echo "Python:"
                    python3 --version

                    echo "Creating virtual environment..."
                    rm -rf .venv
                    python3 -m venv .venv

                    echo "Installing pip..."
                    .venv/bin/python -m pip install --upgrade pip

                    if [ -f requirements.txt ]; then
                        echo "Installing requirements..."
                        .venv/bin/python -m pip install -r requirements.txt
                    fi

                    echo "Installing pytest..."
                    .venv/bin/python -m pip install pytest

                    echo "Running tests..."

                    if find . -maxdepth 2 -type f \\( -name '*test*.py' -o -name 'test_*.py' \\) | grep -q .; then
                        .venv/bin/python -m pytest -q --junitxml=test-results.xml
                    else
                        echo "No Python test files found."
                        echo "Creating empty JUnit report."
                        cat > test-results.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="boardgame-tests" tests="0" failures="0" errors="0" skipped="0"></testsuite>
EOF
                    fi
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo '===== SONARQUBE ANALYSIS ====='

                script {
                    def scanner = tool 'sonar-scanner'

                    withSonarQubeEnv('sonarqube') {
                        sh """
                            ${scanner}/bin/sonar-scanner
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                echo '===== SONARQUBE QUALITY GATE ====='

                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                echo '===== TRIVY FILESYSTEM SCAN ====='

                sh '''
                    trivy fs \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        .
                '''
            }
        }

        stage('Build Image') {
            steps {
                echo '===== DOCKER BUILD ====='

                sh '''
                    docker --version

                    docker build \
                        -t ${FULL_IMAGE} \
                        .

                    docker images | grep boardgame
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                echo '===== TRIVY IMAGE SCAN ====='

                sh '''
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        ${FULL_IMAGE}
                '''
            }
        }

        stage('Push Image') {
            steps {
                echo '===== PUSH IMAGE ====='

                /*
                 * Jenkins credential ID:
                 * dockerhub-credentials
                 *
                 * Replace DOCKERHUB_USERNAME with your Docker Hub
                 * username or configure it as a Jenkins environment variable.
                 */

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "$DOCKERHUB_PASSWORD" | \
                            docker login \
                            -u "$DOCKERHUB_USERNAME" \
                            --password-stdin

                        docker tag \
                            ${FULL_IMAGE} \
                            ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}

                        docker tag \
                            ${FULL_IMAGE} \
                            ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest

                        docker push \
                            ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}

                        docker push \
                            ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to GKE') {
            steps {
                echo '===== DEPLOY TO GKE ====='

                /*
                 * This stage assumes that the AWS Jenkins agent
                 * has gcloud installed and authenticated.
                 *
                 * Configure your GCP/GKE values below.
                 */

                sh '''
                    gcloud --version

                    gcloud container clusters get-credentials \
                        ${GKE_CLUSTER} \
                        --zone ${GKE_ZONE} \
                        --project ${GCP_PROJECT}

                    kubectl get nodes

                    kubectl apply -f k8s/

                    kubectl rollout status \
                        deployment/boardgame \
                        --timeout=180s
                '''
            }
        }
    }

    post {

        always {

            echo '===== TEST RESULTS ====='

            junit(
                allowEmptyResults: true,
                testResults: 'test-results.xml'
            )

            echo '===== CLEANING WORKSPACE ====='

            cleanWs()
        }

        success {

            echo '''
            ========================================
              DEVSECOPS PIPELINE SUCCESSFUL
            ========================================

              Checkout       : SUCCESS
              Tests           : SUCCESS
              SonarQube       : SUCCESS
              Quality Gate    : SUCCESS
              Trivy FS        : SUCCESS
              Docker Build    : SUCCESS
              Trivy Image     : SUCCESS
              Docker Push     : SUCCESS
              GKE Deployment  : SUCCESS

            ========================================
            '''
        }

        failure {

            echo '''
            ========================================
              DEVSECOPS PIPELINE FAILED
            ========================================

              Check the failed stage above.

            ========================================
            '''

            sh '''
                echo "===== DOCKER STATUS ====="
                docker ps -a || true

                echo "===== DOCKER IMAGES ====="
                docker images || true
            '''
        }
    }
}
