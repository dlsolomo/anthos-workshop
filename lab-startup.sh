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

# Install Tools
mkdir -p $WORK_DIR/bin
echo "### "
echo "### Begin Tools install"
echo "### "
## Install kubectx
curl -sLO https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx
chmod +x kubectx
mv kubectx $WORK_DIR/bin
# Install Kops
curl -sLO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"'
 -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
mv kops-linux-amd64 $WORK_DIR/bin/kops
# Install nomos
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos nomos
chmod +x nomos
mv nomos $WORK_DIR/bin


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
