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

        /*
         * =========================================================
         * 1. CHECKOUT
         * =========================================================
         */
        stage('Checkout') {
            steps {
                echo '===== CHECKOUT ====='

                checkout scm

                sh '''
                    echo "===== Git Commit ====="
                    git rev-parse --short HEAD

                    echo "===== Jenkins Host ====="
                    hostname

                    echo "===== Jenkins User ====="
                    whoami
                '''
            }
        }


        /*
         * =========================================================
         * 2. PYTHON TEST
         * =========================================================
         */
        stage('Python Test') {
            steps {
                echo '===== PYTHON TEST ====='

                sh '''
                    set -e

                    echo "===== Python Version ====="
                    python3 --version

                    echo "===== Create Virtual Environment ====="
                    rm -rf .venv
                    python3 -m venv .venv

                    echo "===== Upgrade pip ====="
                    .venv/bin/python -m pip install --upgrade pip

                    echo "===== Install Development Dependencies ====="

                    if [ -f requirements-dev.txt ]; then
                        .venv/bin/python -m pip install -r requirements-dev.txt
                    else
                        .venv/bin/python -m pip install -r requirements.txt
                        .venv/bin/python -m pip install pytest pytest-cov
                    fi

                    echo "===== Verify pytest ====="
                    .venv/bin/python -m pytest --version

                    echo "===== Run Tests ====="

                    if find tests -type f -name '*.py' 2>/dev/null | grep -q .; then

                        .venv/bin/python -m pytest \
                            -q \
                            --junitxml=test-results.xml \
                            --cov=. \
                            --cov-report=xml:coverage.xml

                    else

                        echo "No Python test files found."

                        cat > test-results.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="boardgame-tests"
           tests="0"
           failures="0"
           errors="0"
           skipped="0">
</testsuite>
EOF

                    fi
                '''
            }
        }


        /*
         * =========================================================
         * 3. SONARQUBE ANALYSIS
         * =========================================================
         */
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


        /*
         * =========================================================
         * 4. SONARQUBE QUALITY GATE
         * =========================================================
         */
        stage('SonarQube Quality Gate') {
            steps {

                echo '===== SONARQUBE QUALITY GATE ====='

                timeout(time: 5, unit: 'MINUTES') {

                    waitForQualityGate abortPipeline: true
                }
            }
        }


        /*
         * =========================================================
         * 5. TRIVY FILESYSTEM SCAN
         * =========================================================
         */
        stage('Trivy Filesystem Scan') {
            steps {

                echo '===== TRIVY FILESYSTEM SCAN ====='

                sh '''
                    set -e

                    trivy fs \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        .
                '''
            }
        }


        /*
         * =========================================================
         * 6. DOCKER BUILD
         * =========================================================
         */
        stage('Docker Build') {
            steps {

                echo '===== DOCKER BUILD ====='

                sh '''
                    set -e

                    echo "===== Docker Version ====="
                    docker --version

                    echo "===== Building Image ====="

                    docker build \
                        -t "${FULL_IMAGE}" \
                        .

                    echo "===== Docker Image ====="

                    docker images | grep boardgame
                '''
            }
        }


        /*
         * =========================================================
         * 7. TRIVY IMAGE SCAN
         * =========================================================
         */
        stage('Trivy Image Scan') {
            steps {

                echo '===== TRIVY IMAGE SCAN ====='

                sh '''
                    set -e

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        "${FULL_IMAGE}"
                '''
            }
        }


        /*
         * =========================================================
         * 8. PUSH TO DOCKER HUB
         * =========================================================
         */
        stage('Push to Docker Hub') {
            steps {

                echo '===== DOCKER HUB PUSH ====='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "===== Docker Hub Login ====="

                        echo "$DOCKERHUB_PASSWORD" | \
                            docker login \
                            --username "$DOCKERHUB_USERNAME" \
                            --password-stdin

                        echo "===== Tag Versioned Image ====="

                        docker tag \
                            "${FULL_IMAGE}" \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "===== Tag Latest Image ====="

                        docker tag \
                            "${FULL_IMAGE}" \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"

                        echo "===== Push Versioned Image ====="

                        docker push \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "===== Push Latest Image ====="

                        docker push \
                            "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"

                        echo "===== Docker Hub Logout ====="

                        docker logout
                    '''
                }
            }
        }


        /*
         * =========================================================
         * 9. DEPLOY TO GKE
         * =========================================================
         */
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

                        echo "===== kubectl Version ====="

                        kubectl version --client

                        echo "===== GKE Nodes ====="

                        kubectl get nodes

                        echo "===== Create Namespace ====="

                        kubectl apply -f k8s/namespace.yaml

                        echo "===== Prepare Docker Image ====="

                        DOCKER_IMAGE="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "Image:"
                        echo "${DOCKER_IMAGE}"

                        echo "===== Update Kubernetes Deployment ====="

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "===== Apply Kubernetes Manifests ====="

                        kubectl apply -f k8s/

                        echo "===== Kubernetes Resources ====="

                        kubectl get all -n boardgame

                        echo "===== Wait for Deployment ====="

                        kubectl rollout status \
                            deployment/boardgame-api \
                            -n boardgame \
                            --timeout=180s

                        echo "===== Deployment Status ====="

                        kubectl get deployment \
                            boardgame-api \
                            -n boardgame

                        echo "===== Pod Status ====="

                        kubectl get pods \
                            -n boardgame \
                            -o wide

                        echo "===== Service Status ====="

                        kubectl get service \
                            boardgame-api \
                            -n boardgame

                        echo "===== GKE DEPLOYMENT SUCCESSFUL ====="
                    '''
                }
            }
        }
    }


    /*
     * =============================================================
     * POST ACTIONS
     * =============================================================
     */
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
========================================================
           DEVSECOPS PIPELINE SUCCESS
========================================================

Checkout                  : SUCCESS
Python Tests              : SUCCESS
SonarQube Analysis        : SUCCESS
SonarQube Quality Gate    : SUCCESS
Trivy Filesystem Scan     : SUCCESS
Docker Build              : SUCCESS
Trivy Image Scan          : SUCCESS
Docker Hub Push           : SUCCESS
GKE Deployment            : SUCCESS

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
