pipeline {

    agent any

    environment {
        APP_NAME   = 'boardgame-app'
        IMAGE_TAG  = "${BUILD_NUMBER}"

        // Kubernetes details from your repository
        K8S_NAMESPACE = 'boardgame'
        K8S_DEPLOYMENT = 'boardgame-api'
        K8S_CONTAINER = 'boardgame-api'

        // Jenkins configuration names
        SONAR_SERVER = 'sonarqube'
        SONAR_SCANNER = 'sonar-scanner'
    }

    options {
        timestamps()

        timeout(
            time: 30,
            unit: 'MINUTES'
        )

        buildDiscarder(
            logRotator(
                numToKeepStr: '10'
            )
        )
    }

    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================

        stage('Checkout') {
            steps {

                echo '========================================'
                echo '              CHECKOUT'
                echo '========================================'

                checkout scm

                sh '''
                    set -e

                    echo "Repository:"
                    git remote -v

                    echo "Commit:"
                    git rev-parse --short HEAD

                    echo "Host:"
                    hostname

                    echo "User:"
                    whoami
                '''
            }
        }


        // =========================================================
        // 2. PYTHON TEST
        // =========================================================

        stage('Python Test') {
            steps {

                echo '========================================'
                echo '            PYTHON TEST'
                echo '========================================'

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

                    .venv/bin/python -m pip install \
                        -r requirements.txt

                    echo "Installing pytest..."

                    .venv/bin/python -m pip install pytest

                    echo "Checking pytest..."

                    .venv/bin/python -m pytest --version

                    echo "Running tests..."

                    .venv/bin/python -m pytest \
                        -q \
                        --junitxml=test-results.xml

                    echo "Python tests completed successfully."
                '''
            }

            post {
                always {

                    junit(
                        allowEmptyResults: true,
                        testResults: 'test-results.xml'
                    )
                }
            }
        }


        // =========================================================
        // 3. SONARQUBE ANALYSIS
        // =========================================================

        stage('SonarQube Analysis') {
            steps {

                echo '========================================'
                echo '         SONARQUBE ANALYSIS'
                echo '========================================'

                script {

                    // IMPORTANT:
                    // Use Jenkins-managed SonarQube Scanner.
                    // Do NOT call "sonar-scanner" directly.

                    def scannerHome = tool "${SONAR_SCANNER}"

                    withSonarQubeEnv("${SONAR_SERVER}") {

                        sh """
                            set -e

                            echo "SonarQube Scanner location:"
                            echo "${scannerHome}"

                            echo "SonarQube Scanner version:"

                            ${scannerHome}/bin/sonar-scanner \
                                --version

                            echo "Running SonarQube analysis..."

                            ${scannerHome}/bin/sonar-scanner

                            echo "SonarQube analysis completed."
                        """
                    }
                }
            }
        }


        // =========================================================
        // 4. SONARQUBE QUALITY GATE
        // =========================================================

        stage('SonarQube Quality Gate') {
            steps {

                echo '========================================'
                echo '       SONARQUBE QUALITY GATE'
                echo '========================================'

                timeout(
                    time: 15,
                    unit: 'MINUTES'
                ) {

                    waitForQualityGate(
                        abortPipeline: true
                    )
                }
            }
        }


        // =========================================================
        // 5. TRIVY FILESYSTEM SCAN
        // =========================================================

        stage('Trivy Filesystem Scan') {
            steps {

                echo '========================================'
                echo '       TRIVY FILESYSTEM SCAN'
                echo '========================================'

                sh '''
                    set -e

                    echo "Trivy version:"

                    trivy --version

                    echo "Running filesystem scan..."

                    trivy fs \
                        --severity HIGH,CRITICAL \
                        --ignore-unfixed \
                        --exit-code 1 \
                        --no-progress \
                        .

                    echo "Trivy filesystem scan completed successfully."
                '''
            }
        }


        // =========================================================
        // 6. DOCKER BUILD
        // =========================================================

        stage('Docker Build') {
            steps {

                echo '========================================'
                echo '             DOCKER BUILD'
                echo '========================================'

                sh '''
                    set -e

                    echo "Docker version:"

                    docker --version

                    echo "Testing Docker access..."

                    docker info > /dev/null

                    echo "Building image:"

                    echo "${APP_NAME}:${IMAGE_TAG}"

                    docker build \
                        --pull \
                        --no-cache \
                        -t "${APP_NAME}:${IMAGE_TAG}" \
                        .

                    echo "Docker image created:"

                    docker images "${APP_NAME}:${IMAGE_TAG}"
                '''
            }
        }


        // =========================================================
        // 7. TRIVY IMAGE SCAN
        // =========================================================

        stage('Trivy Image Scan') {
            steps {

                echo '========================================'
                echo '          TRIVY IMAGE SCAN'
                echo '========================================'

                sh '''
                    set -e

                    echo "Scanning image:"

                    echo "${APP_NAME}:${IMAGE_TAG}"

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --ignore-unfixed \
                        --exit-code 1 \
                        --no-progress \
                        "${APP_NAME}:${IMAGE_TAG}"

                    echo "Trivy image scan completed successfully."
                '''
            }
        }


        // =========================================================
        // 8. PUSH TO DOCKER HUB
        // =========================================================

        stage('Push to Docker Hub') {
            steps {

                echo '========================================'
                echo '          DOCKER HUB PUSH'
                echo '========================================'

                withCredentials(
                    [
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKERHUB_USERNAME',
                            passwordVariable: 'DOCKERHUB_PASSWORD'
                        )
                    ]
                ) {

                    sh '''
                        set -e

                        DOCKER_IMAGE="${DOCKERHUB_USERNAME}/${APP_NAME}:${IMAGE_TAG}"

                        echo "Docker Hub image:"
                        echo "${DOCKER_IMAGE}"

                        echo "Logging into Docker Hub..."

                        echo "${DOCKERHUB_PASSWORD}" | \
                            docker login \
                            --username "${DOCKERHUB_USERNAME}" \
                            --password-stdin

                        echo "Tagging image..."

                        docker tag \
                            "${APP_NAME}:${IMAGE_TAG}" \
                            "${DOCKER_IMAGE}"

                        echo "Pushing image..."

                        docker push "${DOCKER_IMAGE}"

                        echo "Docker image pushed successfully."

                        docker logout
                    '''
                }
            }
        }


        // =========================================================
        // 9. GKE CONNECTION TEST
        // =========================================================

        stage('GKE Connection Test') {
            steps {

                echo '========================================'
                echo '          GKE CONNECTION TEST'
                echo '========================================'

                withCredentials(
                    [
                        file(
                            credentialsId: 'gke-kubeconfig',
                            variable: 'KUBECONFIG'
                        )
                    ]
                ) {

                    sh '''
                        set -e

                        echo "kubectl version:"

                        kubectl version --client

                        echo "GKE nodes:"

                        kubectl get nodes

                        echo "GKE connection successful."
                    '''
                }
            }
        }


        // =========================================================
        // 10. DEPLOY TO GKE
        // =========================================================

        stage('Deploy to GKE') {
            steps {

                echo '========================================'
                echo '            DEPLOY TO GKE'
                echo '========================================'

                withCredentials(
                    [
                        file(
                            credentialsId: 'gke-kubeconfig',
                            variable: 'KUBECONFIG'
                        ),

                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKERHUB_USERNAME',
                            passwordVariable: 'DOCKERHUB_PASSWORD'
                        )
                    ]
                ) {

                    sh '''
                        set -e

                        DOCKER_IMAGE="${DOCKERHUB_USERNAME}/${APP_NAME}:${IMAGE_TAG}"

                        echo "Docker image for Kubernetes:"
                        echo "${DOCKER_IMAGE}"

                        echo "Checking GKE connection..."

                        kubectl get nodes

                        echo "Creating/updating namespace..."

                        kubectl apply \
                            -f k8s/namespace.yaml

                        echo "Preparing Kubernetes deployment..."

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "Applying Kubernetes manifests..."

                        kubectl apply \
                            -f k8s/

                        echo "Checking deployment..."

                        kubectl get deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"

                        echo "Waiting for rollout..."

                        kubectl rollout status \
                            deployment/"${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}" \
                            --timeout=180s

                        echo "Deployment successful."

                        echo "Pods:"

                        kubectl get pods \
                            -n "${K8S_NAMESPACE}" \
                            -o wide

                        echo "Services:"

                        kubectl get services \
                            -n "${K8S_NAMESPACE}"

                        echo "Deployment details:"

                        kubectl describe deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"

                        echo "========================================"
                        echo "       GKE DEPLOYMENT SUCCESSFUL"
                        echo "========================================"
                    '''
                }
            }
        }
    }


    // =============================================================
    // POST ACTIONS
    // =============================================================

    post {

        success {

            echo '''
====================================================
           DEVSECOPS PIPELINE SUCCESS
====================================================

Checkout                  : SUCCESS
Python Tests              : SUCCESS
SonarQube Analysis        : SUCCESS
SonarQube Quality Gate    : SUCCESS
Trivy Filesystem Scan     : SUCCESS
Docker Build              : SUCCESS
Trivy Image Scan          : SUCCESS
Docker Hub Push           : SUCCESS
GKE Connection             : SUCCESS
GKE Deployment            : SUCCESS

====================================================
        APPLICATION DEPLOYED TO GKE
====================================================
'''
        }


        failure {

            echo '''
====================================================
           DEVSECOPS PIPELINE FAILED
====================================================

Check the Console Output for the failed stage.

====================================================
'''
        }


        always {

            echo 'Cleaning temporary Python environment...'

            sh '''
                rm -rf .venv || true
            '''

            echo 'Docker images on Jenkins:'

            sh '''
                docker images "${APP_NAME}" || true
            '''
        }
    }
}
