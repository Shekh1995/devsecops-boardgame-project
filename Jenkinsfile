pipeline {

    agent any

    environment {

        // ============================================================
        // DOCKER
        // ============================================================
        DOCKER_IMAGE = "shekhar013/boardgame-app"
        FULL_IMAGE   = "shekhar013/boardgame-app:${BUILD_NUMBER}"

        // ============================================================
        // SONARQUBE
        // ============================================================
        SONARQUBE_SERVER = "sonarqube"

        // ============================================================
        // JENKINS CREDENTIALS
        // ============================================================
        DOCKER_CREDENTIALS    = "dockerhub-credentials"
        KUBECONFIG_CREDENTIALS = "gke-kubeconfig"

        // ============================================================
        // GKE
        // ============================================================
        K8S_NAMESPACE  = "boardgame"
        K8S_DEPLOYMENT = "boardgame-api"
        K8S_CONTAINER   = "boardgame-api"
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    stages {

        // ============================================================
        // 1. CHECKOUT
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
        // 2. PYTHON TEST
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

                    echo "Installing dependencies..."

                    .venv/bin/python -m pip install --upgrade pip

                    .venv/bin/python -m pip install -r requirements.txt

                    echo "Installing pytest..."

                    .venv/bin/python -m pip install pytest

                    echo "Running tests..."

                    .venv/bin/python -m pytest \
                        -q \
                        --junitxml=test-results.xml

                    echo "Python tests PASSED."
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
        // 3. SONARQUBE ANALYSIS
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

                    echo "SonarScanner path:"
                    echo "${scannerHome}"

                    withSonarQubeEnv('sonarqube') {

                        sh """
                            set -e

                            echo "Testing SonarScanner..."

                            ${scannerHome}/bin/sonar-scanner --version

                            echo "Running SonarQube analysis..."

                            ${scannerHome}/bin/sonar-scanner

                            echo "SonarQube analysis completed successfully."
                        """
                    }
                }
            }
        }


        // ============================================================
        // 4. SONARQUBE QUALITY GATE
        // ============================================================
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

                        echo "Quality Gate Status: ${qualityGate.status}"

                        if (qualityGate.status == 'OK') {

                            echo "SonarQube Quality Gate PASSED."

                        } else {

                            echo "WARNING: SonarQube Quality Gate is ${qualityGate.status}"

                            echo "Continuing pipeline for lab deployment."
                        }
                    }
                }
            }
        }


        // ============================================================
        // 5. TRIVY FILESYSTEM SCAN
        // ============================================================
        stage('Trivy Filesystem Scan') {

            steps {

                echo '========================================'
                echo '       TRIVY FILESYSTEM SCAN'
                echo '========================================'

                sh '''
                    set +e

                    echo "Running Trivy filesystem scan..."

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

                        echo "WARNING:"
                        echo "HIGH/CRITICAL vulnerabilities detected."
                        echo "Continuing pipeline for lab deployment."

                    else

                        echo "Trivy filesystem scan PASSED."

                    fi

                    exit 0
                '''
            }
        }


        // ============================================================
        // 6. DOCKER BUILD
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

                    echo "Building image:"
                    echo "${FULL_IMAGE}"

                    docker build \
                        --pull \
                        --no-cache \
                        -t "${FULL_IMAGE}" \
                        .

                    echo "Docker build PASSED."

                    docker images "${FULL_IMAGE}"
                '''
            }
        }


        // ============================================================
        // 7. TRIVY IMAGE SCAN
        // ============================================================
        stage('Trivy Image Scan') {

            steps {

                echo '========================================'
                echo '          TRIVY IMAGE SCAN'
                echo '========================================'

                sh '''
                    set +e

                    echo "Scanning image:"
                    echo "${FULL_IMAGE}"

                    trivy image \
                        --scanners vuln \
                        --severity HIGH,CRITICAL \
                        --no-progress \
                        "${FULL_IMAGE}"

                    TRIVY_EXIT=$?

                    echo "Trivy image exit code: ${TRIVY_EXIT}"

                    if [ ${TRIVY_EXIT} -ne 0 ]; then

                        echo ""
                        echo "WARNING:"
                        echo "HIGH/CRITICAL image vulnerabilities detected."
                        echo "Continuing pipeline for lab deployment."
                        echo ""

                    else

                        echo "Trivy image scan PASSED."

                    fi

                    exit 0
                '''
            }
        }


        // ============================================================
        // 8. DOCKER HUB PUSH
        // ============================================================
        stage('Push to Docker Hub') {

            steps {

                echo '========================================'
                echo '          DOCKER HUB PUSH'
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
                            --username "${DOCKER_USERNAME}" \
                            --password-stdin

                        echo "Pushing image:"
                        echo "${FULL_IMAGE}"

                        docker push "${FULL_IMAGE}"

                        docker logout

                        echo "Docker Hub push PASSED."
                    '''
                }
            }
        }


        // ============================================================
        // 9. GKE CONNECTION TEST
        // ============================================================
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

                        echo "kubectl version:"
                        kubectl version --client

                        echo "GKE nodes:"

                        kubectl get nodes

                        echo "GKE connection PASSED."
                    '''
                }
            }
        }


        // ============================================================
        // 10. DEPLOY TO GKE
        // ============================================================
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

                        echo "Namespace:"
                        echo "${K8S_NAMESPACE}"

                        echo "Deployment:"
                        echo "${K8S_DEPLOYMENT}"

                        echo "Container:"
                        echo "${K8S_CONTAINER}"

                        echo "Docker image:"
                        echo "${FULL_IMAGE}"


                        echo "Applying namespace..."

                        kubectl apply \
                            -f k8s/namespace.yaml


                        echo "Preparing deployment manifest..."

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g" \
                            k8s/deployment.yaml


                        echo "Applying Kubernetes deployment..."

                        kubectl apply \
                            -f k8s/deployment.yaml \
                            -f k8s/service.yaml \
                            -f k8s/ingress.yaml


                        echo "Checking deployment..."

                        kubectl get deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"


                        echo "Checking pods..."

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
                            echo "          ROLLOUT FAILED"
                            echo "========================================"

                            echo "Deployment description:"

                            kubectl describe deployment \
                                "${K8S_DEPLOYMENT}" \
                                -n "${K8S_NAMESPACE}" || true


                            echo "Pods:"

                            kubectl get pods \
                                -n "${K8S_NAMESPACE}" \
                                -o wide || true


                            echo "Pod description:"

                            kubectl describe pods \
                                -n "${K8S_NAMESPACE}" || true


                            echo "Kubernetes events:"

                            kubectl get events \
                                -n "${K8S_NAMESPACE}" \
                                --sort-by=.lastTimestamp || true

                            exit 1
                        fi


                        echo "========================================"
                        echo "       GKE DEPLOYMENT SUCCESS"
                        echo "========================================"


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
            echo '              CLEANUP'
            echo '========================================'

            sh '''
                rm -rf .venv || true
            '''
        }

        success {

            echo '''
====================================================
           DEVSECOPS PIPELINE SUCCESS
====================================================

Checkout             : PASSED
Python Tests         : PASSED
SonarQube Analysis   : PASSED
Quality Gate         : CHECKED
Trivy Filesystem     : COMPLETED
Docker Build         : PASSED
Trivy Image          : COMPLETED
Docker Hub Push      : PASSED
GKE Connection       : PASSED
GKE Deployment       : PASSED

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
