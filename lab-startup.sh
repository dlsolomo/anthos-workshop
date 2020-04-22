gcloud services enable \
    cloudresourcemanager.googleapis.com \
    container.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    serviceusage.googleapis.com \
    sourcerepo.googleapis.com \
    iamcredentials.googleapis.com \
    stackdriver.googleapis.com \
    compute.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    meshca.googleapis.com \
    meshtelemetry.googleapis.com \
    meshconfig.googleapis.com \
    anthos.googleapis.com

cd anthos-workshop

# setup environment
export BASE_DIR=$PWD
echo $BASE_DIR
export WORK_DIR=$BASE_DIR/workdir
echo $WORK_DIR
export PATH=$PATH:$WORK_DIR/bin:
export PROJECT_ID=$DEVSHELL_PROJECT_ID
gcloud config set project ${PROJECT_ID}
export CLUSTER_NAME=central
export CLUSTER_LOCATION=us-central1-b

#Install Anthos CLI and Components
sudo gcloud components install kpt anthoscli alpha
sudo gcloud components update
kpt pkg get \
https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm .

#Setup Anthos Configuration
kpt cfg set asm gcloud.core.project ${PROJECT_ID}
kpt cfg set asm cluster-name ${CLUSTER_NAME}
kpt cfg set asm gcloud.compute.zone ${CLUSTER_LOCATION}

# Create GKE Cluster with ASM
anthoscli apply -f asm

# Install Tree
sudo apt-get install tree
source $BASE_DIR/common/manage-state.sh
