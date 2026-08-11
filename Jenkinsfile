pipeline {

    agent any

    environment {

        // ------------------------------------------------
        // Application
        // ------------------------------------------------
        APP_NAME = 'boardgame-app'

        // Jenkins BUILD_NUMBER creates a unique image tag
        IMAGE_TAG = "${BUILD_NUMBER}"

        // Docker Hub repository
        // CHANGE THIS if your Docker Hub username/repository is different
        DOCKER_IMAGE = "YOUR_DOCKERHUB_USERNAME/boardgame-app:${BUILD_NUMBER}"

        // ------------------------------------------------
        // SonarQube
        // ------------------------------------------------
        SONARQUBE_SERVER = 'sonarqube'
        SONAR_PROJECT_KEY = 'boardgame-devsecops'

        // ------------------------------------------------
        // GKE
        // ------------------------------------------------
        GKE_NAMESPACE = 'default'

        // Kubernetes deployment name
        K8S_DEPLOYMENT = 'boardgame-app'

        // Kubernetes service name
        K8S_SERVICE = 'boardgame-service'
    }

    options {

        timestamps()

        // Do not keep unlimited builds
        buildDiscarder(
            logRotator(
                numToKeepStr: '10'
            )
        )

        // Stop pipeline if it runs longer than 30 minutes
        timeout(
            time: 30,
            unit: 'MINUTES'
        )
    }

    stages {

        // ==================================================
        // 1. CHECKOUT
        // ==================================================

        stage('Checkout') {

            steps {

                echo '========================================'
                echo '          CHECKOUT'
                echo '========================================'

                checkout scm

                sh '''
                    set -e

                    echo "Repository:"
                    git remote -v

                    echo "Git commit:"
                    git rev-parse --short HEAD

                    echo "Jenkins host:"
                    hostname

                    echo "Jenkins user:"
                    whoami
                '''
            }
        }


        // ==================================================
        // 2. PYTHON TEST
        // ==================================================

        stage('Python Test') {

            steps {

                echo '========================================'
                echo '          PYTHON TEST'
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

                    .venv/bin/python -m pip install -r requirements.txt

                    echo "Installing pytest..."

                    .venv/bin/python -m pip install pytest

                    echo "Running pytest..."

                    .venv/bin/python -m pytest -q \
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


        // ==================================================
        // 3. SONARQUBE ANALYSIS
        // ==================================================

        stage('SonarQube Analysis') {

            steps {

                echo '========================================'
                echo '       SONARQUBE ANALYSIS'
                echo '========================================'

                script {

                    withSonarQubeEnv("${SONARQUBE_SERVER}") {

                        sh '''
                            set -e

                            echo "Running SonarQube analysis..."

                            sonar-scanner \
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                              -Dsonar.projectName=${SONAR_PROJECT_KEY} \
                              -Dsonar.sources=. \
                              -Dsonar.exclusions=".venv/**,**/__pycache__/**,**/*.pyc"

                            echo "SonarQube analysis completed."
                        '''
                    }
                }
            }
        }


        // ==================================================
        // 4. SONARQUBE QUALITY GATE
        // ==================================================

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


        // ==================================================
        // 5. TRIVY FILESYSTEM SCAN
        // ==================================================

        stage('Trivy Filesystem Scan') {

            steps {

                echo '========================================'
                echo '       TRIVY FILESYSTEM SCAN'
                echo '========================================'

                sh '''
                    set -e

                    echo "Trivy version:"
                    trivy --version

                    echo "Running filesystem security scan..."

                    trivy fs \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --exit-code 1 \
                      --no-progress \
                      .
                '''
            }
        }


        // ==================================================
        // 6. DOCKER BUILD
        // ==================================================

        stage('Docker Build') {

            steps {

                echo '========================================'
                echo '             DOCKER BUILD'
                echo '========================================'

                sh '''
                    set -e

                    echo "Docker version:"
                    docker --version

                    echo "Docker access test:"
                    docker info > /dev/null

                    echo "Building Docker image..."

                    docker build \
                      --no-cache \
                      -t ${APP_NAME}:${IMAGE_TAG} \
                      .

                    echo "Docker image created:"

                    docker images ${APP_NAME}:${IMAGE_TAG}
                '''
            }
        }


        // ==================================================
        // 7. TRIVY IMAGE SCAN
        // ==================================================

        stage('Trivy Image Scan') {

            steps {

                echo '========================================'
                echo '          TRIVY IMAGE SCAN'
                echo '========================================'

                sh '''
                    set -e

                    echo "Scanning Docker image..."

                    trivy image \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --exit-code 1 \
                      --no-progress \
                      ${APP_NAME}:${IMAGE_TAG}

                    echo "Trivy image scan completed successfully."
                '''
            }
        }


        // ==================================================
        // 8. TAG DOCKER IMAGE
        // ==================================================

        stage('Tag Docker Image') {

            steps {

                echo '========================================'
                echo '          TAG DOCKER IMAGE'
                echo '========================================'

                sh '''
                    set -e

                    echo "Local image:"
                    docker images ${APP_NAME}:${IMAGE_TAG}

                    echo "Docker Hub image:"
                    echo "${DOCKER_IMAGE}"

                    docker tag \
                        ${APP_NAME}:${IMAGE_TAG} \
                        ${DOCKER_IMAGE}

                    echo "Image tagged successfully."
                '''
            }
        }


        // ==================================================
        // 9. PUSH TO DOCKER HUB
        // ==================================================

        stage('Push to Docker Hub') {

            steps {

                echo '========================================'
                echo '          PUSH DOCKER IMAGE'
                echo '========================================'

                withCredentials(
                    [
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]
                ) {

                    sh '''
                        set -e

                        echo "Logging into Docker Hub..."

                        echo "${DOCKER_PASSWORD}" | \
                            docker login \
                            -u "${DOCKER_USERNAME}" \
                            --password-stdin

                        echo "Pushing image..."

                        docker push "${DOCKER_IMAGE}"

                        echo "Docker image pushed successfully."

                        docker logout
                    '''
                }
            }
        }


        // ==================================================
        // 10. GKE CONNECTION TEST
        // ==================================================

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

                        echo "Testing connection to GKE..."

                        kubectl version --client

                        kubectl get nodes

                        echo "GKE connection successful."
                    '''
                }
            }
        }


        // ==================================================
        // 11. DEPLOY TO GKE
        // ==================================================

        stage('Deploy to GKE') {

            steps {

                echo '========================================'
                echo '             DEPLOY TO GKE'
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

                        echo "Using Kubernetes namespace:"
                        echo "${GKE_NAMESPACE}"

                        echo "Current Kubernetes context:"
                        kubectl config current-context

                        echo "Checking cluster:"
                        kubectl get nodes

                        echo "Checking deployment..."

                        kubectl get deployment \
                            ${K8S_DEPLOYMENT} \
                            -n ${GKE_NAMESPACE} \
                            || true

                        echo "Updating Docker image..."

                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            ${K8S_DEPLOYMENT}=${DOCKER_IMAGE} \
                            -n ${GKE_NAMESPACE}

                        echo "Waiting for rollout..."

                        kubectl rollout status \
                            deployment/${K8S_DEPLOYMENT} \
                            -n ${GKE_NAMESPACE} \
                            --timeout=5m

                        echo "Deployment successful."

                        echo "Current pods:"

                        kubectl get pods \
                            -n ${GKE_NAMESPACE} \
                            -o wide

                        echo "Current services:"

                        kubectl get svc \
                            -n ${GKE_NAMESPACE}
                    '''
                }
            }
        }
    }


    // ====================================================
    // POST ACTIONS
    // ====================================================

    post {

        success {

            echo '''
===============================================
       DEVSECOPS PIPELINE SUCCESS
===============================================

Checkout             : SUCCESS
Python Tests          : SUCCESS
SonarQube             : SUCCESS
Quality Gate          : SUCCESS
Trivy FS Scan         : SUCCESS
Docker Build          : SUCCESS
Trivy Image Scan      : SUCCESS
Docker Hub Push       : SUCCESS
GKE Connection        : SUCCESS
GKE Deployment        : SUCCESS

Application deployed successfully.
===============================================
'''
        }

        failure {

            echo '''
===============================================
       DEVSECOPS PIPELINE FAILED
===============================================

Check the failed stage in Console Output.

===============================================
'''
        }

        always {

            sh '''
                echo "Cleaning temporary files..."

                rm -rf .venv || true
            '''

            sh '''
                echo "Docker images currently present:"

                docker images ${APP_NAME} || true
            '''
        }
    }
}
