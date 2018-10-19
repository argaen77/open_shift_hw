#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

echo "Setup acces rights for grading jenkins"
oc -n ${GUID}-jenkins policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins

echo "Setting up Jenkins"
oc -n $GUID-jenkins new-app -f ../templates/jenkins.yaml -p MEMORY_LIMIT=2Gi -p MEMORY_REQUEST=2Gi -p VOLUME_CAPACITY=4Gi
oc -n $GUID-jenkins rollout status dc/jenkins -w

echo "Buid skopeo pod"
cat ../templates/jenkins_skopeo/Dockerfile | oc -n $GUID-jenkins new-build --name=jenkins-slave-maven -D -
oc -n $GUID-jenkins logs -f bc/jenkins-slave-maven
oc -n $GUID-jenkins new-app -f ../templates/jenkins-configmap.yaml --param GUID=${GUID}

echo "Creating and configuring Build Configs for 3 pipelines"
oc -n $GUID-jenkins new-build ${REPO} --name="mlbparks-pipeline" --strategy=pipeline --context-dir="MLBParks"
oc -n $GUID-jenkins set env bc/mlbparks-pipeline CLUSTER=${CLUSTER} GUID=${GUID}

oc -n $GUID-jenkins new-build ${REPO} --name="nationalparks-pipeline" --strategy=pipeline --context-dir="Nationalparks"
oc -n $GUID-jenkins set env bc/nationalparks-pipeline CLUSTER=${CLUSTER} GUID=${GUID}

oc -n $GUID-jenkins new-build ${REPO} --name="parksmap-pipeline" --strategy=pipeline --context-dir="ParksMap"
oc -n $GUID-jenkins set env bc/parksmap-pipeline CLUSTER=${CLUSTER} GUID=${GUID}
