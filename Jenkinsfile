pipeline {
    agent any

    stages {
        stage('Build and Run') {            
            steps {
                sh 'docker compose -f ./docker-compose-database.yml up -d --build'

                withCredentials([
                    file(credentialsId: 'phpSiteNameCom', variable: 'phpSiteNameCom')
                ]) {
                    sh 'cp "$phpSiteNameCom" /php-sites/site-name-com/.env'
                    sh 'domain=site-name-com docker compose up -d --build'
                }
            }
        }
    }
}
