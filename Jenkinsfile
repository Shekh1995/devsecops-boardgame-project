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


        /*
         * =========================================================
         * 2. PYTHON TEST
         * =========================================================
         */
        stage('Install and Test') {
            steps {
                echo '===== INSTALL AND TEST ====='

                sh '''
                    set -e

                    echo "Python version:"
                    python3 --version

                    echo "Creating virtual environment..."
                    rm -rf .venv
                    python3 -m venv .venv

                    echo "Upgrading pip..."
                    .venv/bin/python -m pip install --upgrade pip

                    echo "Installing application requirements..."
                    if [ -f requirements.txt ]; then
                        .venv/bin/python -m pip install -r requirements.txt
                    fi

                    echo "Installing pytest..."
                    .venv/bin/python -m pip install pytest

                    echo "Running tests..."

                    if find . -maxdepth 2 -type f \
                        \\( -name '*test*.py' -o -name 'test_*.py' \\) \
                        | grep -q .; then

                        .venv/bin/python -m pytest -q \
                            --junitxml=test-results.xml

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
         * 3. SONARQUBE
         * =========================================================
         */
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


        /*
         * =========================================================
         * 4. SONARQUBE QUALITY GATE
         * =========================================================
         */
        stage('Quality Gate') {
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
        stage('Build Docker Image') {
            steps {
                echo '===== DOCKER BUILD ====='

                sh '''
                    set -e

                    docker --version

                    echo "Building image:"
                    echo "${FULL_IMAGE}"

                    docker build \
                        -t "${FULL_IMAGE}" \
                        .

                    echo "Docker image created:"
                    docker images | grep boardgame
                '''
            }
        }


        /*
         * =========================================================
         * 7. TRIVY DOCKER IMAGE SCAN
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
        stage('Push Image to Docker Hub') {
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

                        echo "===== KUBECTL VERSION ====="
                        kubectl version --client

                        echo "===== GKE NODES ====="
                        kubectl get nodes

                        echo "===== CREATE/UPDATE NAMESPACE ====="
                        kubectl apply -f k8s/namespace.yaml

                        echo "===== SETTING DOCKER IMAGE ====="

                        DOCKER_IMAGE="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "Deploying image:"
                        echo "${DOCKER_IMAGE}"

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "===== APPLY KUBERNETES MANIFESTS ====="

                        kubectl apply -f k8s/

                        echo "===== KUBERNETES RESOURCES ====="

                        kubectl get all -n boardgame

                        echo "===== WAITING FOR ROLLOUT ====="

                        kubectl rollout status \
                            deployment/boardgame-api \
                            -n boardgame \
                            --timeout=180s

                        echo "===== DEPLOYMENT STATUS ====="

                        kubectl get deployment \
                            boardgame-api \
                            -n boardgame

                        echo "===== POD STATUS ====="

                        kubectl get pods \
                            -n boardgame \
                            -o wide

                        echo "===== SERVICE STATUS ====="

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

            echo '===== PUBLISHING TEST RESULTS ====='

            junit(
                allowEmptyResults: true,
                testResults: 'test-results.xml'
            )

            echo '===== CLEANING WORKSPACE ====='

            cleanWs()
        }


        success {

            echo '''
            ================================================
              DEVSECOPS PIPELINE SUCCESSFUL
            ================================================

              Checkout              : SUCCESS
              Python Tests          : SUCCESS
              SonarQube             : SUCCESS
              Quality Gate          : SUCCESS
              Trivy FS Scan         : SUCCESS
              Docker Build          : SUCCESS
              Trivy Image Scan      : SUCCESS
              Docker Hub Push       : SUCCESS
              GKE Deployment        : SUCCESS

            ================================================
            '''
        }


        failure {

            echo '''
            ================================================
              DEVSECOPS PIPELINE FAILED
            ================================================

              Check the failed stage in Console Output.

            ================================================
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
