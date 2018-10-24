#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"
# Code to set up the parks development project.

# Jenkis access rights
oc -n ${GUID}-parks-dev policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins
oc -n ${GUID}-parks-dev policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod
oc -n ${GUID}-parks-dev policy add-role-to-user view --serviceaccount=default

# MongoDB
oc -n ${GUID}-parks-dev new-app mongodb-persistent --name=mongodb -p MONGODB_USER=mongodb -p MONGODB_PASSWORD=mongodb -p MONGODB_DATABASE=parks
oc -n ${GUID}-parks-dev rollout status dc/mongodb -w
oc -n ${GUID}-parks-dev create configmap parksdb-conf \
       --from-literal=DB_HOST=mongodb \
       --from-literal=DB_PORT=27017 \
       --from-literal=DB_USERNAME=mongodb \
       --from-literal=DB_PASSWORD=mongodb \
       --from-literal=DB_NAME=parks

# MLBParks
oc -n ${GUID}-parks-dev new-build --binary=true --name=mlbparks jboss-eap70-openshift:1.7
oc -n ${GUID}-parks-dev new-app ${GUID}-parks-dev/mlbparks:0.0-0 --allow-missing-imagestream-tags=true --name=mlbparks -l type=parksmap-backend
oc -n ${GUID}-parks-dev set triggers dc/mlbparks --remove-all
oc -n ${GUID}-parks-dev expose dc/mlbparks --port 8080

# Probes
oc -n ${GUID}-parks-dev set probe dc/mlbparks --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-dev set probe dc/mlbparks --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/

# ConfigMap
oc -n ${GUID}-parks-dev create configmap mlbparks-conf --from-literal=APPNAME="MLB Parks (Dev)"
oc -n ${GUID}-parks-dev set env dc/mlbparks --from=configmap/parksdb-conf
oc -n ${GUID}-parks-dev set env dc/mlbparks --from=configmap/mlbparks-conf

# Init DB
oc -n ${GUID}-parks-dev set deployment-hook dc/mlbparks --post -- curl -s http://mlbparks:8080/ws/data/load/

# NationalParks
oc -n ${GUID}-parks-dev new-build --binary=true --name=nationalparks redhat-openjdk18-openshift:1.2
oc -n ${GUID}-parks-dev new-app ${GUID}-parks-dev/nationalparks:0.0-0 --allow-missing-imagestream-tags=true --name=nationalparks -l type=parksmap-backend
oc -n ${GUID}-parks-dev set triggers dc/nationalparks --remove-all
oc -n ${GUID}-parks-dev expose dc/nationalparks --port 8080

# Probes
oc -n ${GUID}-parks-dev set probe dc/nationalparks --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-dev set probe dc/nationalparks --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/

# ConfigMap
oc -n ${GUID}-parks-dev create configmap nationalparks-conf --from-literal=APPNAME="National Parks (Dev)"
oc -n ${GUID}-parks-dev set env dc/nationalparks --from=configmap/parksdb-conf
oc -n ${GUID}-parks-dev set env dc/nationalparks --from=configmap/nationalparks-conf

# Post deployment hook to populate database once deployment strategy completes
oc -n ${GUID}-parks-dev set deployment-hook dc/nationalparks --post -- curl -s http://nationalparks:8080/ws/data/load/

# ParksMap
oc -n ${GUID}-parks-dev new-build --binary=true --name=parksmap redhat-openjdk18-openshift:1.2
oc -n ${GUID}-parks-dev new-app ${GUID}-parks-dev/parksmap:0.0-0 --allow-missing-imagestream-tags=true --name=parksmap -l type=parksmap-frontend
oc -n ${GUID}-parks-dev set triggers dc/parksmap --remove-all
oc -n ${GUID}-parks-dev expose dc/parksmap --port 8080

# Probes
oc -n ${GUID}-parks-dev set probe dc/parksmap --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-dev set probe dc/parksmap --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
# ConfigMap
oc -n ${GUID}-parks-dev create configmap parksmap-conf --from-literal=APPNAME="ParksMap (Dev)"
oc -n ${GUID}-parks-dev set env dc/parksmap --from=configmap/parksmap-conf

# Expose frontend service
oc -n ${GUID}-parks-dev expose svc/parksmap
