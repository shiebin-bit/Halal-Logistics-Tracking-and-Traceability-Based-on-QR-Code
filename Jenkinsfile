pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
        skipDefaultCheckout(true)
    }

    parameters {
        string(
            name: 'BRANCH_TO_BUILD',
            defaultValue: 'main',
            description: 'Git branch to build from the GitHub repository.'
        )
        booleanParam(
            name: 'RUN_FRONTEND_CHECKS',
            defaultValue: false,
            description: 'Run flutter analyze and flutter test. Keep this disabled on Windows Jenkins unless symlink support / Developer Mode is enabled.'
        )
        booleanParam(
            name: 'RUN_DOCKER_BUILD',
            defaultValue: true,
            description: 'Build the backend Docker image after tests pass.'
        )
    }

    environment {
        REPO_URL = 'https://github.com/shiebin-bit/Halal-Logistics-Tracking-and-Traceability-Based-on-QR-Code.git'
        GIT_CREDENTIALS_ID = 'shiebin-bit'
        BACKEND_DIR = 'backend/halal_traceability_api'
        FRONTEND_DIR = 'frontend/halal_traceability_app'
        BACKEND_IMAGE = "halaltrack-backend:${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                deleteDir()
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.BRANCH_TO_BUILD}"]],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [],
                    userRemoteConfigs: [[
                        url: env.REPO_URL,
                        credentialsId: env.GIT_CREDENTIALS_ID
                    ]]
                ])
            }
        }

        stage('Backend Tests') {
            steps {
                script {
                    runBackendTests(env.BACKEND_DIR)
                }
            }
        }

        stage('Frontend Checks') {
            when {
                expression { return params.RUN_FRONTEND_CHECKS }
            }
            steps {
                script {
                    runFrontendChecks(env.FRONTEND_DIR)
                }
            }
        }

        stage('Build Backend Docker Image') {
            when {
                expression { return params.RUN_DOCKER_BUILD }
            }
            steps {
                script {
                    buildBackendImage(env.BACKEND_IMAGE)
                }
            }
        }
    }

    post {
        success {
            echo "Jenkins pipeline completed successfully."
            echo "Built branch: ${params.BRANCH_TO_BUILD}"
            echo "Backend image tag: ${env.BACKEND_IMAGE}"
        }
        always {
            cleanWs(deleteDirs: true, disableDeferredWipeout: true)
        }
    }
}

void runBackendTests(String backendDir) {
    dir(backendDir) {
        if (isUnix()) {
            sh '''
                set -eux
                composer install --no-interaction --no-progress --prefer-dist
                cp .env.testing .env
                mkdir -p bootstrap/cache
                mkdir -p storage/framework/cache/data
                mkdir -p storage/framework/sessions
                mkdir -p storage/framework/testing
                mkdir -p storage/framework/views
                mkdir -p storage/logs
                php artisan config:clear
                php artisan test
            '''
        } else {
            bat '''
                composer install --no-interaction --no-progress --prefer-dist
                copy /Y .env.testing .env
                if not exist bootstrap\\cache mkdir bootstrap\\cache
                if not exist storage\\framework\\cache\\data mkdir storage\\framework\\cache\\data
                if not exist storage\\framework\\sessions mkdir storage\\framework\\sessions
                if not exist storage\\framework\\testing mkdir storage\\framework\\testing
                if not exist storage\\framework\\views mkdir storage\\framework\\views
                if not exist storage\\logs mkdir storage\\logs
                php artisan config:clear
                php artisan test
            '''
        }
    }
}

void runFrontendChecks(String frontendDir) {
    dir(frontendDir) {
        if (isUnix()) {
            sh '''
                set -eux
                flutter pub get
                flutter analyze
                flutter test
            '''
        } else {
            bat '''
                flutter pub get
                flutter analyze
                flutter test
            '''
        }
    }
}

void buildBackendImage(String imageTag) {
    if (isUnix()) {
        sh """
            set -eux
            docker build -t "${imageTag}" backend/halal_traceability_api
        """
    } else {
        bat """
            docker build -t "${imageTag}" backend\\halal_traceability_api
        """
    }
}
