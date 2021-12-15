#!/bin/bash

BASE_DIR=deploy
# define namespaces you wanna deploy 
declare -a environments=( "prod" "ci" "staging" )

# define teams for whom  namespaces are created
declare -a teams=( "uber" "supper")

# If it is true then the script will create namespaces without the team suffix
TEAM_PROJECT=false

if [ $TEAM_PROJECT == true ]
then
  NS_FORMAT=ENV
else
  NS_FORMAT=ENV-TEAM
fi
# Rancher  project and cluster id
PROJECT=yyyyyyy
CLUSTER=xxxxxxx

# LOGGING Output and Flow 
LOGGING=true
LOGGING_URL=
LOGGING_TENANT=
LOGGING_SECRET_NAME=banzaicloud


# Secrets usernaame and password are expected to exist as environment variables. Following exports shoult not be used for defining them. They are there just  for testing.
export PASSWORD=password
export USERNAME=username

# Cleanup any existing data
rm -rf ./$BASE_DIR

# Create base directory
mkdir ./$BASE_DIR

cat <<EOF >./$BASE_DIR/kustomization.yaml
resources:
EOF
 
cat <<EOF >./$BASE_DIR/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    field.cattle.io/projectId: $CLUSTER:$PROJECT
    lifecycle.cattle.io/create.namespace-auth: "true"
  finalizers:
  - controller.cattle.io/namespace-auth
  labels:
    field.cattle.io/projectId: $PROJECT
  name: $NS_FORMAT
spec:
  finalizers:
  - kubernetes
EOF

cat <<EOF >./$BASE_DIR/logging-output.yaml
apiVersion: logging.banzaicloud.io/v1beta1
kind: Output
metadata:
  name: $NS_FORMAT-output
  namespace: $NS_FORMAT
spec:
  loki:
    configure_kubernetes_labels: true
    extract_kubernetes_labels: true
    insecure_tls: true
    tenant: LOGGING_TENANT
    url: LOGGING_URL
    password:
      valueFrom:
        secretKeyRef:
          key: password
          name: LOGGING_SECRET_NAME
    username:
      valueFrom:
        secretKeyRef:
          key: username
          name: LOGGING_SECRET_NAME
EOF

cat <<EOF >./$BASE_DIR/logging-flow.yaml
apiVersion: logging.banzaicloud.io/v1beta1
kind: Flow
metadata:
  name: $NS_FORMAT-flow
  namespace: $NS_FORMAT
spec:
  globalOutputRefs: []
  localOutputRefs:
  - $NS_FORMAT-output
EOF

cat <<EOF >./$BASE_DIR/logging-secret.yaml
apiVersion: v1
data:
  password: ${PASSWORD}
  username: ${USERNAME}
kind: Secret
metadata:
  name: LOGGING_SECRET_NAME
  namespace: $NS_FORMAT
type: Opaque
EOF


for i in "${teams[@]}"
do
  mkdir ./$BASE_DIR/$i
  cp ./$BASE_DIR/kustomization.yaml ./$BASE_DIR/$i/kustomization.yaml
  for a in "${environments[@]}"
  do	
    cp ./$BASE_DIR/namespace.yaml ./$BASE_DIR/$i/$a.yaml
    declare -a filenames=("${a}")
	
    if [ $LOGGING == true ]
    then
      cp ./$BASE_DIR/logging-output.yaml ./$BASE_DIR/$i/$a-logging-output.yaml
      cp ./$BASE_DIR/logging-flow.yaml ./$BASE_DIR/$i/$a-logging-flow.yaml
      cp ./$BASE_DIR/logging-secret.yaml ./$BASE_DIR/$i/$a-logging-secret.yaml
	 
      sed -i "s/LOGGING_TENANT/$LOGGING_TENANT/g" ./$BASE_DIR/$i/*.yaml
      sed -i "s,LOGGING_URL,$LOGGING_URL,g" ./$BASE_DIR/$i/*.yaml
      sed -i "s/LOGGING_SECRET_NAME/$LOGGING_SECRET_NAME/g" ./$BASE_DIR/$i/*.yaml
     
      filenames+=("${a}-logging-output" "${a}-logging-flow" "${a}-logging-secret")
    fi
	sed -i "s/ENV/$a/g" ./$BASE_DIR/$i/*.yaml
    sed -i "s/TEAM/$i/g" ./$BASE_DIR/$i/*.yaml
    for file in "${filenames[@]}"
    do
      echo "- ${file}.yaml" >>  ./$BASE_DIR/$i/kustomization.yaml
    done
  done
  # remove the --dry-run flag to really create resoruces in the cluster
  kubectl create --dry-run=client -k ./$BASE_DIR/$i/
done
