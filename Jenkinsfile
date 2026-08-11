pipeline {

    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {

        // ============================================================
        // DOCKER
        // ============================================================
        DOCKER_IMAGE = "shekhar013/boardgame-app:${BUILD_NUMBER}"

        // ============================================================
        // KUBERNETES / GKE
        // ============================================================
        K8S_NAMESPACE  = "boardgame"
        K8S_DEPLOYMENT = "boardgame-api"

        // ============================================================
        // SONARQUBE
        // ============================================================
        SONAR_PROJECT_KEY  = "boardgame-devsecops"
        SONAR_PROJECT_NAME = "boardgame-devsecops"
    }

    stages {

        // ============================================================
        // CHECKOUT
        // ============================================================
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

                    echo "Jenkins host:"
                    hostname

                    echo "Jenkins user:"
                    whoami
                '''
            }
        }


        // ============================================================
        // PYTHON TEST
        // ============================================================
        stage('Python Test') {

            steps {

                echo '========================================'
                echo '             PYTHON TEST'
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

                    echo "Installing test dependencies..."

                    .venv/bin/python -m pip install pytest pytest-cov

                    echo "Checking pytest..."

                    .venv/bin/python -m pytest --version

                    echo "Running tests..."

                    .venv/bin/python -m pytest -q \
                        --junitxml=test-results.xml \
                        --cov=. \
                        --cov-report=xml:coverage.xml

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


        // ============================================================
        // SONARQUBE ANALYSIS
        // ============================================================
        stage('SonarQube Analysis') {

            steps {

                echo '========================================'
                echo '          SONARQUBE ANALYSIS'
                echo '========================================'

                script {

                    def scannerHome = tool(
                        name: 'sonar-scanner',
                        type: 'hudson.plugins.sonar.SonarRunnerInstallation'
                    )

                    withSonarQubeEnv('sonarqube') {

                        sh """
                            set -e

                            echo "SonarQube Scanner:"
                            ${scannerHome}/bin/sonar-scanner --version

                            echo "Running SonarQube analysis..."

                            ${scannerHome}/bin/sonar-scanner \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.projectName=${SONAR_PROJECT_NAME} \
                                -Dsonar.sources=. \
                                -Dsonar.python.version=3.14 \
                                -Dsonar.python.coverage.reportPaths=coverage.xml \
                                -Dsonar.python.xunit.reportPath=test-results.xml \
                                -Dsonar.exclusions=".venv/**,.git/**,tests/**,monitoring/**,**/__pycache__/**,**/*.pyc"

                            echo "SonarQube analysis completed successfully."
                        """
                    }
                }
            }
        }


        // ============================================================
        // SONARQUBE QUALITY GATE
        // ============================================================
        stage('SonarQube Quality Gate') {

            steps {

                echo '========================================'
                echo '         SONARQUBE QUALITY GATE'
                echo '========================================'

                timeout(time: 15, unit: 'MINUTES') {

                    script {

                        def qualityGate = waitForQualityGate(
                            abortPipeline: false
                        )

                        echo "SonarQube Quality Gate: ${qualityGate.status}"

                        if (qualityGate.status == 'OK') {

                            echo "SonarQube Quality Gate PASSED."

                        } else {

                            echo "WARNING: SonarQube Quality Gate returned ${qualityGate.status}"

                            echo "Continuing pipeline so Docker, Trivy and GKE can be tested."
                        }
                    }
                }
            }
        }


        // ============================================================
        // TRIVY FILESYSTEM SCAN
        // ============================================================
        stage('Trivy Filesystem Scan') {

            steps {

                echo '========================================'
                echo '       TRIVY FILESYSTEM SCAN'
                echo '========================================'

                sh '''
                    set -e

                    echo "Trivy version:"

                    trivy --version

                    echo "Running filesystem vulnerability scan..."

                    trivy fs \
                        --scanners vuln,secret \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        --skip-dirs .venv \
                        --skip-dirs .git \
                        .
                '''
            }
        }


        // ============================================================
        // PREPARE DOCKER BUILD
        // ============================================================
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


        // ============================================================
        // DOCKER BUILD
        // ============================================================
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

                    echo "${DOCKER_IMAGE}"

                    docker build \
                        --pull \
                        -t "${DOCKER_IMAGE}" \
                        .

                    echo "Docker image built successfully."

                    docker images "${DOCKER_IMAGE}"
                '''
            }
        }


        // ============================================================
        // TRIVY IMAGE SCAN
        // ============================================================
        stage('Trivy Image Scan') {

            steps {

                echo '========================================'
                echo '          TRIVY IMAGE SCAN'
                echo '========================================'

                sh '''
                    set -e

                    echo "Scanning Docker image:"

                    echo "${DOCKER_IMAGE}"

                    trivy image \
                        --scanners vuln \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        "${DOCKER_IMAGE}"

                    echo "Trivy image scan completed successfully."
                '''
            }
        }


        // ============================================================
        // PUSH TO DOCKER HUB
        // ============================================================
        stage('Push to Docker Hub') {

            steps {

                echo '========================================'
                echo '          PUSH TO DOCKER HUB'
                echo '========================================'

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "Logging into Docker Hub..."

                        echo "${DOCKER_PASSWORD}" | \
                            docker login \
                            --username "${DOCKER_USERNAME}" \
                            --password-stdin

                        echo "Pushing image:"

                        echo "${DOCKER_IMAGE}"

                        docker push "${DOCKER_IMAGE}"

                        echo "Docker image pushed successfully."

                        docker logout
                    '''
                }
            }
        }


        // ============================================================
        // GKE CONNECTION TEST
        // ============================================================
        stage('GKE Connection Test') {

            steps {

                echo '========================================'
                echo '          GKE CONNECTION TEST'
                echo '========================================'

                withCredentials([
                    file(
                        credentialsId: 'gke-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {

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


        // ============================================================
        // DEPLOY TO GKE
        // ============================================================
        stage('Deploy to GKE') {

            steps {

                echo '========================================'
                echo '             DEPLOY TO GKE'
                echo '========================================'

                withCredentials([
                    file(
                        credentialsId: 'gke-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "========================================"
                        echo "DEPLOYING IMAGE"
                        echo "========================================"

                        echo "${DOCKER_IMAGE}"

                        echo "Checking Kubernetes cluster..."

                        kubectl get nodes

                        echo "Creating namespace if required..."

                        kubectl apply -f k8s/namespace.yaml

                        echo "Updating Kubernetes image..."

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "Applying Kubernetes manifests..."

                        kubectl apply -f k8s/

                        echo "Deployment status:"

                        kubectl get deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"

                        echo "Pods before rollout:"

                        kubectl get pods \
                            -n "${K8S_NAMESPACE}" \
                            -o wide

                        echo "Waiting for rollout..."

                        if ! kubectl rollout status \
                            deployment/"${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}" \
                            --timeout=180s
                        then

                            echo "========================================"
                            echo "       ROLLOUT FAILED"
                            echo "========================================"

                            echo "Deployment details:"

                            kubectl describe deployment \
                                "${K8S_DEPLOYMENT}" \
                                -n "${K8S_NAMESPACE}" || true

                            echo "Pod status:"

                            kubectl get pods \
                                -n "${K8S_NAMESPACE}" \
                                -o wide || true

                            echo "Pod details:"

                            kubectl describe pods \
                                -n "${K8S_NAMESPACE}" || true

                            echo "Recent events:"

                            kubectl get events \
                                -n "${K8S_NAMESPACE}" \
                                --sort-by=.lastTimestamp || true

                            echo "Pod logs:"

                            kubectl logs \
                                -n "${K8S_NAMESPACE}" \
                                -l app=boardgame-api \
                                --all-containers=true \
                                --tail=100 || true

                            exit 1
                        fi

                        echo "========================================"
                        echo "       GKE DEPLOYMENT SUCCESS"
                        echo "========================================"

                        echo "Deployment:"

                        kubectl get deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"

                        echo "Pods:"

                        kubectl get pods \
                            -n "${K8S_NAMESPACE}" \
                            -o wide

                        echo "Services:"

                        kubectl get svc \
                            -n "${K8S_NAMESPACE}"

                        echo "Ingress:"

                        kubectl get ingress \
                            -n "${K8S_NAMESPACE}" || true
                    '''
                }
            }
        }
    }


    // ================================================================
    // POST ACTIONS
    // ================================================================
    post {

        always {

            echo '========================================'
            echo '               CLEANUP'
            echo '========================================'

            sh '''
                rm -rf .venv || true
            '''

            echo "Docker images currently present:"

            sh '''
                docker images boardgame-app || true
            '''
        }


        success {

            echo '''
========================================================
             DEVSECOPS PIPELINE SUCCESS
========================================================

Checkout                  SUCCESS
Python Tests              SUCCESS
SonarQube Analysis        SUCCESS
SonarQube Quality Gate    CHECKED
Trivy Filesystem          SUCCESS
Docker Build              SUCCESS
Trivy Image Scan          SUCCESS
Docker Hub Push           SUCCESS
GKE Connection            SUCCESS
GKE Deployment            SUCCESS

========================================================
'''
        }


        failure {

            echo '''
========================================================
             DEVSECOPS PIPELINE FAILED
========================================================

Check the failed stage in Console Output.

========================================================
'''
        }
    }
}
