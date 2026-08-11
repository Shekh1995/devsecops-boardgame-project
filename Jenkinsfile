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
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh '''
                    python3 --version
                    pip3 --version
                    pip3 install -r requirements.txt
                    pytest
                '''
            }
        }

        stage('GKE Connection Test') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'gke-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        kubectl get nodes
                        kubectl get pods -A
                    '''
                }
            }
        }
    }
}
