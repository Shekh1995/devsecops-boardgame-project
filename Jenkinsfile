pipeline {

    agent any

    environment {

        // ============================================================
        // DOCKER HUB
        // ============================================================
        DOCKER_IMAGE = "shekhar013/boardgame-app"
        FULL_IMAGE   = "shekhar013/boardgame-app:${BUILD_NUMBER}"

        // ============================================================
        // SONARQUBE
        // ============================================================
        SONARQUBE_SERVER  = "sonarqube"
        SONAR_PROJECT_KEY = "boardgame-devsecops"

        // ============================================================
        // JENKINS CREDENTIALS
        // ============================================================
        DOCKER_CREDENTIALS   = "dockerhub-credentials"
        KUBECONFIG_CREDENTIALS = "gke-kubeconfig"

        // ============================================================
        // KUBERNETES
        // These MUST match k8s/*.yaml
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

                    echo "Host:"
                    hostname

                    echo "User:"
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

                    echo "SonarScanner path:"
                    echo "${scannerHome}"

                    withSonarQubeEnv("${SONARQUBE_SERVER}") {

                        sh """
                            set -e

                            echo "Testing SonarScanner..."

                            ${scannerHome}/bin/sonar-scanner --version

                            echo "Running SonarQube analysis..."

                            ${scannerHome}/bin/sonar-scanner \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.projectName=boardgame-devsecops \
                                -Dsonar.sources=. \
                                -Dsonar.exclusions=".venv/**,.git/**,**/__pycache__/**,**/*.pyc"

                            echo "SonarQube analysis completed."
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
                echo '        SONARQUBE QUALITY GATE'
                echo '========================================'

                script {

                    timeout(time: 15, unit: 'MINUTES') {

                        def qualityGate = waitForQualityGate(
                            abortPipeline: false
                        )

                        echo "Quality Gate: ${qualityGate.status}"

                        if (qualityGate.status == 'OK') {

                            echo "SonarQube Quality Gate PASSED."

                        } else {

                            echo "WARNING: SonarQube Quality Gate = ${qualityGate.status}"

                            echo "Continuing pipeline for lab deployment."
                        }
                    }
                }
            }
        }


        // ============================================================
        // TRIVY FILESYSTEM
        // ============================================================
        stage('Trivy Filesystem Scan') {

            steps {

                echo '========================================'
                echo '       TRIVY FILESYSTEM SCAN'
                echo '========================================'

                sh '''
                    set +e

                    trivy fs \
                        --scanners vuln,secret \
                        --severity HIGH,CRITICAL \
                        --no-progress \
                        --skip-dirs .venv \
                        --skip-dirs .git \
                        .

                    RC=$?

                    echo "Trivy filesystem exit code: ${RC}"

                    if [ ${RC} -ne 0 ]; then
                        echo "WARNING: HIGH/CRITICAL findings detected."
                        echo "Continuing for lab deployment."
                    fi

                    exit 0
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

                    echo "Building:"
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
        // TRIVY IMAGE
        // ============================================================
        stage('Trivy Image Scan') {

            steps {

                echo '========================================'
                echo '          TRIVY IMAGE SCAN'
                echo '========================================'

                sh '''
                    set +e

                    echo "Scanning:"
                    echo "${FULL_IMAGE}"

                    trivy image \
                        --scanners vuln \
                        --severity HIGH,CRITICAL \
                        --no-progress \
                        "${FULL_IMAGE}"

                    RC=$?

                    echo "Trivy image exit code: ${RC}"

                    if [ ${RC} -ne 0 ]; then
                        echo "WARNING: HIGH/CRITICAL image vulnerabilities detected."
                        echo "Continuing for lab deployment."
                    fi

                    exit 0
                '''
            }
        }


        // ============================================================
        // DOCKER HUB PUSH
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

                        echo "${DOCKER_PASSWORD}" | docker login \
                            --username "${DOCKER_USERNAME}" \
                            --password-stdin

                        echo "Pushing:"
                        echo "${FULL_IMAGE}"

                        docker push "${FULL_IMAGE}"

                        docker logout

                        echo "Docker Hub push PASSED."
                    '''
                }
            }
        }


        // ============================================================
        // GKE CONNECTION
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

                        echo "kubectl:"
                        kubectl version --client

                        echo "GKE nodes:"

                        kubectl get nodes

                        echo "GKE connection PASSED."
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
                        credentialsId: "${KUBECONFIG_CREDENTIALS}",
                        variable: 'KUBECONFIG'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "Creating/updating namespace..."

                        kubectl apply \
                            -f k8s/namespace.yaml

                        echo "Replacing image placeholder..."

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "Applying Kubernetes manifests..."

                        kubectl apply \
                            -f k8s/deployment.yaml \
                            -f k8s/service.yaml \
                            -f k8s/ingress.yaml

                        echo "Deployment:"
                        kubectl get deployment \
                            "${K8S_DEPLOYMENT}" \
                            -n "${K8S_NAMESPACE}"

                        echo "Pods:"
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
                            echo "        GKE ROLLOUT FAILED"
                            echo "========================================"

                            echo "Deployment:"
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

                            echo "Events:"
                            kubectl get events \
                                -n "${K8S_NAMESPACE}" \
                                --sort-by=.lastTimestamp || true

                            exit 1
                        fi

                        echo "========================================"
                        echo "       GKE DEPLOYMENT SUCCESS"
                        echo "========================================"

                        kubectl get pods \
                            -n "${K8S_NAMESPACE}" \
                            -o wide

                        kubectl get svc \
                            -n "${K8S_NAMESPACE}"

                        kubectl get ingress \
                            -n "${K8S_NAMESPACE}" || true
                    '''
                }
            }
        }
    }


    // ================================================================
    // POST
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

Python Tests          : PASSED
SonarQube Analysis    : COMPLETED
SonarQube Gate        : CHECKED
Trivy Filesystem      : COMPLETED
Docker Build          : PASSED
Trivy Image           : COMPLETED
Docker Hub            : PASSED
GKE Connection        : PASSED
GKE Deployment        : PASSED

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
