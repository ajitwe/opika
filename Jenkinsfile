pipeline {
    agent any

    environment {
        DOCKERHUB_REPO = 'ajitsingh25/opika' // e.g., 'myusername/myapp'
        IMAGE_TAG = "${env.BUILD_NUMBER}" // or use 'latest' for testing
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
                        // Build the Docker image and assign it to dockerImage variable
                        def dockerImage = docker.build("${DOCKERHUB_REPO}:${IMAGE_TAG}", "-f Dockerfile .")
                        // Store the dockerImage in a global variable for later use
                        env.DOCKER_IMAGE = dockerImage
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
                    dockerImage.push("${IMAGE_TAG}")
                    dockerImage.push("latest")  // Optional: Push a "latest" tag for easy access
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
