#!/bin/bash

if [[ $# != 1 ]];then
  echo "Usage: $0 <init|destroy>"
  exit 0
fi

VERSION=latest
STAGE=$1
ID=`whoami`

function check_binary {
 BNR=`which $1`
 if [[ -z "${BNR}" ]];then
   echo "Please make sure $1 installed and present in your PATH environment"
   exit 1
 fi 
}
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


check_binary minikube
check_binary kubectl
check_binary docker

if [[ "${ID}" == "root" ]];then
   echo "Please make sure to run it under regular user, Note: if you use driver virtualbox or podman, you may need special sudoers rights for /usr/bin/podman command etc"
   exit 1
fi


# Let's check is minikube is running
STS=`minikube status`
if [[ "${STS}" == "0" ]];then
 echo "minikube is not running, please start it with correct driver first"
 exit 1
fi  

case $STAGE in 
init | Init | INIT)
 echo "Deploying TEST APP"

RST=`kubectl get deployment  | grep tstapp | wc -l`
if [[ "${RST}" == "1" ]];then
 echo "TST APP already deployed please destroy first"
 exit 1
fi  

# Build image
eval $(minikube docker-env)
docker build -t tstapp:${VERSION} .
# Enable ingress 
minikube addons enable ingress
# create secret for redis server
kubectl create secret generic redis-password --from-literal=redis-password=qwerty

# Deploy redis server
kubectl apply -f k8s/redis_deployment.yml
kubectl apply -f k8s/redis_service.yml
# Deploy tstapp 
kubectl apply -f k8s/tstapp_deployment.yml
kubectl apply -f k8s/tstapp_svc.yml
kubectl apply -f k8s/tstapp_ingres.yml

TSTAPPIP=`kubectl get ing tstapp-ingress | tail -1 | awk '{ print $4}'`
if valid_ip $TSTAPPIP; then GOTIP='True'; else GOTIP='False'; fi
i=0

while [[ $i -lt 10 ]] && [[ "${GOTIP}" == "False" ]]
do
echo "Still didn't get IP address for TST APP"
kubectl get ing tstapp-ingress

TSTAPPIP=`kubectl get ing tstapp-ingress | tail -1 | awk '{ print $4}'`
if valid_ip $TSTAPPIP; then GOTIP='True'; else GOTIP='False'; fi
i=$[$i+1]
sleep 10
done

echo "Please add into /etc/hosts entry: ${TSTAPPIP} counter-app.local"
echo "Open in browser http://counter-app.local/ URL"


 ;;
destroy | Destroy | DESTROY )
 echo "Destroying TEST APP"
RST=`kubectl get deployment  | grep tstapp | wc -l`
if [[ "${RST}" == "0" ]];then
 echo "TST APP doesn't exist"
 exit 1
fi  
 kubectl delete deployment redis-leader
 kubectl delete deployment tstapp
 kubectl delete svc redis-leader
 kubectl delete secrets redis-password
 kubectl delete svc tstapp-svc
 kubectl delete ing tstapp-ingress
 ;;
*)
 echo "Please specify correct action: init or destroy"
 ;;
 esac

