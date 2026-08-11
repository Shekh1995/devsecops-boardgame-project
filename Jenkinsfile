pipeline {

    agent {
        label 'built-in'
    }

    environment {
        IMAGE_NAME = 'boardgame-app'
        IMAGE_TAG  = "${BUILD_NUMBER}"
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
                    echo "Git commit:"
                    git rev-parse --short HEAD

                    echo "Jenkins node:"
                    hostname

                    echo "Jenkins user:"
                    whoami
                '''
            }
        }


        stage('Python Test') {
            steps {
                echo '===== PYTHON TEST ====='

                sh '''
                    set -e

                    echo "Python version:"
                    python3 --version

                    echo "Creating virtual environment..."
                    rm -rf .venv
                    python3 -m venv .venv

                    echo "Upgrading pip..."
                    .venv/bin/python -m pip install --upgrade pip

                    echo "Installing application dependencies..."
                    .venv/bin/python -m pip install -r requirements.txt

                    echo "Installing test dependencies..."

                    if [ -f requirements-dev.txt ]; then
                        .venv/bin/python -m pip install -r requirements-dev.txt
                    else
                        .venv/bin/python -m pip install pytest pytest-cov
                    fi

                    echo "Checking pytest..."
                    .venv/bin/python -m pytest --version

                    echo "Running tests..."

                    .venv/bin/python -m pytest \
                        -q \
                        --junitxml=test-results.xml \
                        --cov=. \
                        --cov-report=xml:coverage.xml
                '''
            }
        }


        stage('SonarQube Analysis') {
            steps {
                echo '===== SONARQUBE ANALYSIS ====='

                script {

                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('sonarqube') {

                        sh """
                            ${scannerHome}/bin/sonar-scanner
                        """
                    }
                }
            }
        }


        stage('SonarQube Quality Gate') {
            steps {
                echo '===== SONARQUBE QUALITY GATE ====='

                timeout(time: 15, unit: 'MINUTES') {

                    waitForQualityGate abortPipeline: true
                }
            }
        }


        stage('Trivy Filesystem Scan') {
            steps {
                echo '===== TRIVY FILESYSTEM SCAN ====='

                sh '''
                    set -e

                    echo "Trivy version:"
                    trivy --version

                    echo "Running filesystem scan..."

                    trivy fs \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        .
                '''
            }
        }


        stage('Docker Build') {
            steps {
                echo '===== DOCKER BUILD ====='

                sh '''
                    set -e

                    echo "Docker version:"
                    docker --version

                    echo "Building Docker image..."

                    docker build \
                        -t "${FULL_IMAGE}" \
                        .

                    echo "Docker image created:"
                    docker images | grep boardgame
                '''
            }
        }


        stage('Trivy Image Scan') {
            steps {
                echo '===== TRIVY IMAGE SCAN ====='

                sh '''
                    set -e

                    echo "Scanning Docker image..."

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        "${FULL_IMAGE}"
                '''
            }
        }


        stage('Push to Docker Hub') {
            steps {
                echo '===== PUSH TO DOCKER HUB ====='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "Logging into Docker Hub..."

                        echo "$DOCKERHUB_PASSWORD" | \
                            docker login \
                            --username "$DOCKERHUB_USERNAME" \
                            --password-stdin

                        echo "Tagging image..."

                        docker tag \
                            "${FULL_IMAGE}" \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        docker tag \
                            "${FULL_IMAGE}" \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"

                        echo "Pushing versioned image..."

                        docker push \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "Pushing latest image..."

                        docker push \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"

                        echo "Logging out..."

                        docker logout
                    '''
                }
            }
        }


        stage('Deploy to GKE') {
            steps {
                echo '===== DEPLOY TO GKE ====='

                withCredentials([
                    file(
                        credentialsId: 'gke-kubeconfig',
                        variable: 'KUBECONFIG'
                    ),

                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "kubectl version:"
                        kubectl version --client

                        echo "Checking GKE connection:"
                        kubectl get nodes

                        echo "Creating namespace..."
                        kubectl apply -f k8s/namespace.yaml

                        echo "Preparing Docker image..."

                        DOCKER_IMAGE="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "Deployment image:"
                        echo "${DOCKER_IMAGE}"

                        echo "Replacing image placeholder..."

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "Applying Kubernetes manifests..."

                        kubectl apply -f k8s/

                        echo "Checking Kubernetes resources..."

                        kubectl get all -n boardgame

                        echo "Waiting for deployment..."

                        kubectl rollout status \
                            deployment/boardgame-api \
                            -n boardgame \
                            --timeout=180s

                        echo "Final deployment status:"

                        kubectl get deployment \
                            boardgame-api \
                            -n boardgame

                        echo "Pods:"

                        kubectl get pods \
                            -n boardgame \
                            -o wide

                        echo "Services:"

                        kubectl get services \
                            -n boardgame

                        echo "===== GKE DEPLOYMENT SUCCESSFUL ====="
                    '''
                }
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
        }

        success {
            echo '''
====================================================
          DEVSECOPS PIPELINE SUCCESS
====================================================

Checkout                 : SUCCESS
Python Tests             : SUCCESS
SonarQube Analysis       : SUCCESS
SonarQube Quality Gate   : SUCCESS
Trivy Filesystem Scan    : SUCCESS
Docker Build             : SUCCESS
Trivy Image Scan         : SUCCESS
Docker Hub Push          : SUCCESS
GKE Deployment           : SUCCESS

====================================================
'''
        }

        failure {
            echo '''
====================================================
          DEVSECOPS PIPELINE FAILED
====================================================

Check the failed stage in Console Output.

====================================================
'''
        }
    }
}
