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

                    echo "Python:"
                    python3 --version

                    echo "Creating virtual environment..."

                    rm -rf .venv

                    python3 -m venv .venv

                    echo "Installing dependencies..."

                    .venv/bin/python -m pip install --upgrade pip

                    .venv/bin/python -m pip install -r requirements.txt

                    echo "Running pytest..."

                    .venv/bin/python -m pytest -q \
                        --junitxml=test-results.xml
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

                timeout(time: 5, unit: 'MINUTES') {

                    waitForQualityGate abortPipeline: true
                }
            }
        }


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


        stage('Docker Build') {
            steps {
                echo '===== DOCKER BUILD ====='

                sh '''
                    set -e

                    docker --version

                    echo "Building:"
                    echo "${FULL_IMAGE}"

                    docker build \
                        -t "${FULL_IMAGE}" \
                        .

                    docker images | grep boardgame
                '''
            }
        }


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

                        echo "Logging into Docker Hub..."

                        echo "$DOCKERHUB_PASSWORD" | \
                            docker login \
                            --username "$DOCKERHUB_USERNAME" \
                            --password-stdin

                        echo "Tagging Docker image..."

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

                        echo "===== KUBECTL ====="

                        kubectl version --client

                        echo "===== GKE NODES ====="

                        kubectl get nodes

                        echo "===== NAMESPACE ====="

                        kubectl apply -f k8s/namespace.yaml

                        echo "===== DOCKER IMAGE ====="

                        DOCKER_IMAGE="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

                        echo "Deploying:"
                        echo "${DOCKER_IMAGE}"

                        echo "===== UPDATE DEPLOYMENT IMAGE ====="

                        sed -i \
                            "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}|g" \
                            k8s/deployment.yaml

                        echo "===== APPLY KUBERNETES MANIFESTS ====="

                        kubectl apply -f k8s/

                        echo "===== WAIT FOR DEPLOYMENT ====="

                        kubectl rollout status \
                            deployment/boardgame-api \
                            -n boardgame \
                            --timeout=180s

                        echo "===== DEPLOYMENT ====="

                        kubectl get deployment \
                            -n boardgame

                        echo "===== PODS ====="

                        kubectl get pods \
                            -n boardgame \
                            -o wide

                        echo "===== SERVICES ====="

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
================================================
       DEVSECOPS PIPELINE SUCCESS
================================================

GitHub                  : SUCCESS
Python Tests            : SUCCESS
SonarQube               : SUCCESS
Quality Gate            : SUCCESS
Trivy FS Scan           : SUCCESS
Docker Build            : SUCCESS
Trivy Image Scan        : SUCCESS
Docker Hub Push         : SUCCESS
GKE Deployment          : SUCCESS

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
        }
    }
}
