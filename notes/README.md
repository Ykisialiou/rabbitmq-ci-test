# Task 1

## Terraform 

Terraform selected, as an industry standard tool, simple enought and with a number of precreated modules that should be used

NOTE: options are -  ARM, pulumi, coding with Microsoft provided SDK. 

## aks module 
AKS terrafrom module selected, as an 'oficially' (Azure oficil github group) supported way to deal with AKS. 
module has no obvious limitations, and should cover the needs we have here



 NOTE: in case of prod deployment module probably should be forked and modified, however for POC setup



 ## write and deploy terraform code


aks.tf is an actual code, using AKS module
vars.tf has only service principal creds, used by cluster itself

autoscaling is disabled as we have strict affinity rule in the next step. We'll have one worker for jenkins controller and other for agents. terraform module allows to enable autoscaling easily.

### NOTE: 
.tfvars used to provide the creds to the installtion here. More accurate way is prefered 
for prod-like systems (vault)

az login (terraform usage is manual here, just az login option is good enought)

### NOTE: 
service principal more prefered way if terrafrom is intended to be used by automation. 

### NOTE: private cluster option seems good for more prod like setups, however for POC it's just AKS cluster as it is to avoid additional network configuration overhead

terraform init
terraform plan
terraform apply

### NOTE: the deployment is ~6 min in my case

## test k8s login. 

az aks install-cli --install-location /home/eugene/bin/kubectl
az aks get-credentials --resource-group myaks-resource-group --name al-devops-test-aks

### NOTE: if you have only kubectl installed login will not work, az aks install-cli should berun to install addditional binary

kubectl get pod -A



# Task 2

## Helm

Is the simplest way to deploy things to k8s, and has pretty big list of software, that can be used
including Jenkins

## Helm chart

'Oficial' Jenkins chart is the best in the situation of POC, we have no too much to configure, however pod affinity rules and ingres are confiurable.

## Affinity

We have a strict demand to split controller and agent pods. The best way to do it in k8s is pod affinity/antyaffinity rules (node affinity can be used also in our case as we have stricly 2 nodes, we can specify one for controlles, other for agent and put pods to  the corresponding node using node selectors)

antyaffinity rules are configured in `jenkins/jenkins-conf.yaml` and we stricly limit the agent pod to be schedulled to node, where we have pod with label `app.kubernetes.io/component: jenkins-controller` which is our controller pod.

## Ingress

We need to have external access to Jenkins. 

The standard (and simplest in our case) to deploy nginx ingress controller (default setting here)

`kubectl create ns  nginx-ingres`

`helm install nginx-ingress ingress-nginx/ingress-nginx     --namespace nginx-ingres     --set controller.replicaCount=2     --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux     --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux     --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux`

create default ingress object for helm chart (chart will do it for us) and use this ingress to route traffic to the Jenkins pods. 


To manage DNS, access to DNS provider should be granted. It could be good to use Azure DNS to manage DNS carefully, however for this case we'll only need one A record. 
`kubectl get ingress jenkins-1615290407`
shows public IP address, assigned to Jekins ingress
A record like IP_ADDRESS jenkins.yakisialiou.xyz should be created and jenkins will be accessable via  this DNS name/url after chart deployment finish.

### NOTE:
security should be considered carefully here in case of prod setup. 
Probably we need Jenkins to be accessed only from inside, right firewal and DNS config can help in this case.

## Install helm chart

We are using `oficial` jekins chart with some prams override, including affinity rules and ingress config
`helm install jenkins/jenkins --generate-name  --values jenkins-conf.yaml`

## Login to Jenkins
chart specifies how to find the password and login to Jenkins

`kubectl exec --namespace default -it svc/jenkins-1615280934 -c jenkins -- /bin/cat /run/secrets/chart-admin-password && echo`

also can be found in secret and then `base64 --decode` the value from secret
kubectl get secret jenkins-1615280934 -o yaml

only Jenkins controller deployed in this case, agents will appear on-demand. 


# Task 3

## rabiitmq docker
For maximum simplicity preinstalled plugin selected, the resulting dockerfile will be super short and will look like

```
FROM rabbitmq:3.8.14
RUN rabbitmq-plugins enable rabbitmq_management
```

## Build a container desicion

To build a container in k8s based Jenkins couple of approaches where tryed. Docker in docker and mounting docker socket looks like bad options, however the issue is well knows and already have propper tooling. To build docker container inside the container and put it to provided registry `kaniko` project exists. 

The selected solution is to run it as a part of Jenkins pipeline.
### NOTE: 
kaniko container by default is just a kaniko binary, so it is no default way to be run in k8s is long running continer where Jenkins can execute it tasks. The possible ways - to fork and rebuild contaier. Or to use the quick workaround. kaniko ships debug containers where busybox tools are located in /busybox directory

Dockerfile(https://github.com/GoogleContainerTools/kaniko/blob/master/deploy/Dockerfile_debug) 

so, to run a container with kaniko in k8s we can do this


```
    image: gcr.io/kaniko-project/executor:debug
    imagePullPolicy: Always
    tty: true
    command:
    - "/busybox/cat"

```

## Create registry

Simple terrafrom code added to create ACR registry. registry.tf file


## Auth

NOTE: This can be done better however done in a simple way. Automted way should be found


Create service principal according to Microsoft docs

ACR_NAME=rabbitmqaldevopstest
SERVICE_PRINCIPAL_NAME=acr-service-principal

# Obtain the full registry ID for subsequent command args
```
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)

# Create the service principal with rights scoped to the registry.
# Default permissions are for docker pull access. Modify the '--role'
# argument value as desired:
# acrpull:     pull only
# acrpush:     push and pull
# owner:       push, pull, and assign roles
SP_PASSWD=$(az ad sp create-for-rbac --name http://$SERVICE_PRINCIPAL_NAME --scopes $ACR_REGISTRY_ID --role acrpush --query password --output tsv)
SP_APP_ID=$(az ad sp show --id http://$SERVICE_PRINCIPAL_NAME --query appId --output tsv)

# Output the service principal's credentials; use these in your services and
# applications to authenticate to the container registry.
echo "Service principal ID: $SP_APP_ID"
echo "Service principal password: $SP_PASSWD"

```
Use this creds with docker

`docker login rabbitmqaldevopstest.azurecr.io`

the credentials will live in 
`/home/eugene/.docker/config.json`

This creds can be mounted to docker container as voulmes and tested locally


`docker run -v /home/eugene/workspace/aks-examples/rabbitmq/Dockerfile:/kaniko/Dockerfile -v /home/eugene/.docker/config.json:/kaniko/.docker/acr/config.json -v /home/eugene/.docker/config.json:/kaniko/.docker/config.json gcr.io/kaniko-project/executor:v1.0.0 --dockerfile=/kaniko/Dockerfile  --destination=rabbitmqaldevopstest.azurecr.io/kaniko-demo:latest --cache=true --context $(pwd) --insecure --skip-tls-verify --skip-tls-verify-pull --insecure-pull`

NOTE: here is some manual steps wich should also be automated

to make kaniko pod work we need additional kubernetes objects to be created. 

`kubectl apply -f config-secret.yaml`

NOTE: this step should be recreted, the creds should be grabbed by Jenkins from creds store and this object should then be generted. For now it's manual
```
---
apiVersion: v1
kind: Secret
metadata:
  name: kaniko-secret
stringData:
  config.json: |-
    {
        "auths": {
            "rabbitmqaldevopstest.azurecr.io": { %PUT login info from dockers config.json %}
            }
        }
    }
```

kubectl apply -f config-secret.yaml

NOTE: this took the most time as all kaniko docs pecifie dfferent login setting and nothing worked. 

## Pipeline

Jenkins multibrach pipeline is super simple here and can be found in Jenkinsfile. It runs kaniko pod and in this pod executes the kaniko executor command with some prametrs, the kaniko will build container and push it to ACR then. 

