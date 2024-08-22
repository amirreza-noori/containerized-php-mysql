pipeline {
    agent any

    stages {
        stage('Build and Run') {            
            steps {
                git 'https://github.com/amirreza-noori/containerized-php-mysql.git'

                sh 'docker compose -f ./docker-compose-database.yml up -d --build'

                withCredentials([
                    file(credentialsId: 'phpSiteDomain1Com', variable: 'phpSiteDomain1Com')
                ]) {
                    sh 'mkdir -p /php-sites/domain1-com/ && cp "$phpSiteDomain1Com" /php-sites/domain1-com/.env'
                    sh 'cp -r ./* /php-sites/domain1-com/ && domain=domain1-com docker compose -f /php-sites/domain1-com/docker-compose.yml up -d --build'
                }

                withCredentials([
                    file(credentialsId: 'phpSiteDomain2Com', variable: 'phpSiteDomain2Com')
                ]) {
                    sh 'mkdir -p /php-sites/domain2-com/ && cp "$phpSiteDomain2Com" /php-sites/domain2-com/.env'
                    sh 'cp -r ./* /php-sites/domain2-com/ && domain=domain2-com docker compose -f /php-sites/domain1-com/docker-compose.yml up -d --build'
                }
            }
        }
    }
}
