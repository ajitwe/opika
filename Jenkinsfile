pipeline {
    agent any

    environment {
        DOCKERHUB_REPO = 'ajitsingh25/opika'  // e.g., 'ajitsingh25/opika'
        IMAGE_TAG = "${env.BUILD_NUMBER}"  // Use build number or 'latest' for testing
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Change the working directory to 'app'
                    dir('app') {
                        // Build the Docker image
                        def dockerImage = docker.build("${DOCKERHUB_REPO}:${IMAGE_TAG}", "-f Dockerfile .")
                        // Store the image name in the environment for later use
                        env.DOCKER_IMAGE = "${DOCKERHUB_REPO}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Login to Docker Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
                        sh 'echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USERNAME --password-stdin'
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    // Use the stored docker image reference for pushing
                    sh "docker push ${env.DOCKER_IMAGE}"
                    // Optionally push the 'latest' tag as well
                    sh "docker tag ${env.DOCKER_IMAGE} ${DOCKERHUB_REPO}:latest"
                    sh "docker push ${DOCKERHUB_REPO}:latest"
                }
            }
        }
    }

    post {
        cleanup {
            script {
                sh 'docker logout'
            }
        }
    }
}
