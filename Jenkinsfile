pipeline {

    agent any

    environment {

        // Docker Hub
        DOCKER_IMAGE = "shekhar013/boardgame-app"
        IMAGE_TAG = "${BUILD_NUMBER}"

        // SonarQube
        SONARQUBE_SERVER = "sonarqube"
        SONAR_PROJECT_KEY = "boardgame-devsecops"

        // Jenkins credentials
        DOCKER_CREDENTIALS = "dockerhub-credentials"
        KUBECONFIG_CREDENTIALS = "gke-kubeconfig"

        // Kubernetes
        K8S_NAMESPACE = "default"
        K8S_DEPLOYMENT = "boardgame-app"
        K8S_CONTAINER = "boardgame-app"

        // Full Docker image
        FULL_IMAGE = "shekhar013/boardgame-app:${BUILD_NUMBER}"
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    stages {

        /*
         * ============================================================
         * CHECKOUT
         * ============================================================
         */
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

                    echo "Git commit:"
                    git rev-parse --short HEAD

                    echo "Jenkins host:"
                    hostname

                    echo "Jenkins user:"
                    whoami
                '''
            }
        }


        /*
         * ============================================================
         * PYTHON TEST
         * ============================================================
         */
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
                    .venv/bin/python -m pip install -r requirements.txt

                    echo "Installing pytest..."
                    .venv/bin/python -m pip install pytest

                    echo "Running pytest..."
                    .venv/bin/python -m pytest -q --junitxml=test-results.xml

                    echo "Python tests completed successfully."
                '''
            }

            post {
                always {
                    junit(
                        testResults: 'test-results.xml',
                        allowEmptyResults: true
                    )
                }
            }
        }


        /*
         * ============================================================
         * SONARQUBE ANALYSIS
         * ============================================================
         */
        stage('SonarQube Analysis') {
            steps {

                echo '========================================'
                echo '          SONARQUBE ANALYSIS'
                echo '========================================'

                script {

                    withSonarQubeEnv("${SONARQUBE_SERVER}") {

                        sh '''
                            set -e

                            echo "Running SonarQube analysis..."

                            sonar-scanner \
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                              -Dsonar.projectName=boardgame-devsecops \
                              -Dsonar.sources=. \
                              -Dsonar.exclusions=.venv/**,**/__pycache__/**,**/*.pyc,.git/**

                            echo "SonarQube analysis completed."
                        '''
                    }
                }
            }
        }


        /*
         * ============================================================
         * SONARQUBE QUALITY GATE
         * ============================================================
         */
        stage('SonarQube Quality Gate') {
            steps {

                echo '========================================'
                echo '        SONARQUBE QUALITY GATE'
                echo '========================================'

                script {

                    timeout(time: 15, unit: 'MINUTES') {

                        def qualityGate = waitForQualityGate(
                            abortPipeline: false
                        )

                        echo "SonarQube Quality Gate: ${qualityGate.status}"

                        if (qualityGate.status != 'OK') {
                            echo "WARNING: SonarQube Quality Gate is ${qualityGate.status}"
                            echo "Continuing pipeline for DevSecOps lab deployment."
                        }
                    }
                }
            }
        }


        /*
         * ============================================================
         * TRIVY FILESYSTEM SCAN
         * ============================================================
         */
        stage('Trivy Filesystem Scan') {
            steps {

                echo '========================================'
                echo '        TRIVY FILESYSTEM SCAN'
                echo '========================================'

                sh '''
                    set +e

                    echo "Trivy version:"
                    trivy --version

                    echo "Running filesystem vulnerability scan..."

                    trivy fs \
                      --scanners vuln,secret \
                      --severity HIGH,CRITICAL \
                      --no-progress \
                      --skip-dirs .venv \
                      --skip-dirs .git \
                      .

                    TRIVY_EXIT=$?

                    echo "Trivy filesystem exit code: ${TRIVY_EXIT}"

                    if [ ${TRIVY_EXIT} -ne 0 ]; then
                        echo "WARNING: HIGH/CRITICAL filesystem findings detected."
                        echo "Continuing pipeline for lab deployment."
                    else
                        echo "Filesystem scan passed."
                    fi

                    exit 0
                '''
            }
        }


        /*
         * ============================================================
         * PREPARE DOCKER
         * ============================================================
         */
        stage('Prepare Docker Build') {
            steps {

                echo '========================================'
                echo '          PREPARE DOCKER BUILD'
                echo '========================================'

                sh '''
                    set -e

                    echo "Removing Python virtual environment..."
                    rm -rf .venv

                    echo "Checking Dockerfile..."
                    test -f Dockerfile

                    echo "Dockerfile found."

                    echo "Dockerfile USER configuration:"
                    grep -n "^USER" Dockerfile || true
                '''
            }
        }


        /*
         * ============================================================
         * DOCKER BUILD
         * ============================================================
         */
        stage('Docker Build') {
            steps {

                echo '========================================'
                echo '             DOCKER BUILD'
                echo '========================================'

                sh '''
                    set -e

                    echo "Docker version:"
                    docker --version

                    echo "Building Docker image:"
                    echo "${FULL_IMAGE}"

                    docker build \
                      --pull \
                      -t "${FULL_IMAGE}" \
                      .

                    echo "Docker image built successfully."

                    docker images "${FULL_IMAGE}"
                '''
            }
        }


        /*
         * ============================================================
         * TRIVY IMAGE SCAN
         * ============================================================
         */
        stage('Trivy Image Scan') {
            steps {

                echo '========================================'
                echo '          TRIVY IMAGE SCAN'
                echo '========================================'

                sh '''
                    set +e

                    echo "Scanning Docker image:"
                    echo "${FULL_IMAGE}"

                    trivy image \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --no-progress \
                      "${FULL_IMAGE}"

                    TRIVY_EXIT=$?

                    echo "Trivy image scan exit code: ${TRIVY_EXIT}"

                    if [ ${TRIVY_EXIT} -ne 0 ]; then
                        echo ""
                        echo "WARNING:"
                        echo "HIGH/CRITICAL vulnerabilities were detected."
                        echo "The pipeline will continue for this DevSecOps lab."
                        echo ""
                    else
                        echo "Trivy image scan passed."
                    fi

                    exit 0
                '''
            }
        }


        /*
         * ============================================================
         * PUSH TO DOCKER HUB
         * ============================================================
         */
        stage('Push to Docker Hub') {
            steps {

                echo '========================================'
                echo '         PUSH TO DOCKER HUB'
                echo '========================================'

                withCredentials([
                    usernamePassword(
                        credentialsId: "${DOCKER_CREDENTIALS}",
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "Logging into Docker Hub..."

                        echo "${DOCKER_PASSWORD}" | docker login \
                            -u "${DOCKER_USERNAME}" \
                            --password-stdin

                        echo "Pushing image:"
                        echo "${FULL_IMAGE}"

                        docker push "${FULL_IMAGE}"

                        echo "Docker image pushed successfully."

                        docker logout
                    '''
                }
            }
        }


        /*
         * ============================================================
         * GKE CONNECTION TEST
         * ============================================================
         */
        stage('GKE Connection Test') {
            steps {

                echo '========================================'
                echo '          GKE CONNECTION TEST'
                echo '========================================'

                withCredentials([
                    file(
                        credentialsId: "${KUBECONFIG_CREDENTIALS}",
                        variable: 'KUBECONFIG'
                    )
                ]) {

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


        /*
         * ============================================================
         * DEPLOY TO GKE
         * ============================================================
         */
        stage('Deploy to GKE') {
            steps {

                echo '========================================'
                echo '             DEPLOY TO GKE'
                echo '========================================'

                withCredentials([
                    file(
                        credentialsId: "${KUBECONFIG_CREDENTIALS}",
                        variable: 'KUBECONFIG'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "Using image:"
                        echo "${FULL_IMAGE}"

                        echo "Checking Kubernetes namespace..."

                        kubectl get namespace "${K8S_NAMESPACE}"

                        echo "Checking existing deployment..."

                        if kubectl get deployment "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}" >/dev/null 2>&1
                        then

                            echo "Deployment exists."
                            echo "Updating image..."

                            kubectl set image deployment/"${K8S_DEPLOYMENT}" \
                                "${K8S_CONTAINER}"="${FULL_IMAGE}" \
                                -n "${K8S_NAMESPACE}"

                        else

                            echo "Deployment does not exist."

                            echo "Creating deployment..."

                            kubectl create deployment "${K8S_DEPLOYMENT}" \
                                --image="${FULL_IMAGE}" \
                                --port=8080 \
                                -n "${K8S_NAMESPACE}"

                        fi

                        echo "Waiting for rollout..."

                        kubectl rollout status \
                            deployment/"${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}" \
                            --timeout=180s

                        echo "Deployment completed."

                        echo "Current pods:"
                        kubectl get pods \
                            -n "${K8S_NAMESPACE}" \
                            -o wide

                        echo "Current deployment:"
                        kubectl get deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"
                    '''
                }
            }
        }
    }


    /*
     * ================================================================
     * POST ACTIONS
     * ================================================================
     */
    post {

        always {

            echo '========================================'
            echo '               CLEANUP'
            echo '========================================'

            sh '''
                rm -rf .venv || true
            '''

            sh '''
                echo "Docker images currently present:"
                docker images "${DOCKER_IMAGE}" || true
            '''
        }

        success {

            echo '''
===============================================
       DEVSECOPS PIPELINE SUCCESS
===============================================

Checkout       : PASSED
Python Tests   : PASSED
SonarQube      : COMPLETED
Trivy FS       : COMPLETED
Docker Build   : PASSED
Trivy Image    : COMPLETED
Docker Hub     : PASSED
GKE Connection : PASSED
GKE Deployment : PASSED

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
    }
}
