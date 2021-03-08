pipeline {
    agent none
    stages {
      stage('Build') {
        agent {
          kubernetes {
            label 'builder'
            defaultContainer 'builder'
            yaml '''       
apiVersion: v1
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - name: builder
    image: gcr.io/kaniko-project/executor:debug
    imagePullPolicy: Always
    tty: true
    command:
    - "/busybox/cat"
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker/
    - name: docker-acr-config
      mountPath: /kaniko/.docker/acr/

  volumes:
  - name: docker-config
    secret:
      secretName: kaniko-secret
  - name: docker-acr-config
    secret:
      secretName: kaniko-secret

'''
          }
        }
      steps { container('builder') {
            script { sh "/kaniko/executor --dockerfile `pwd`/Dockerfile --destination=rabbitmqaldevopstest.azurecr.io/app:${env.BUILD_ID}"} 
            }
      } 
      }
    } 
}    
