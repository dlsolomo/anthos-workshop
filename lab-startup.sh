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

cd ~/anthos-workshop

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
export ISTIO_VERSION=1.4.7

# Install Tools
mkdir -p $WORK_DIR/bin
echo "### "
echo "### Begin Tools install"
echo "### "
# Download Istio
curl -L https://git.io/getLatestIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
cp istio-$ISTIO_VERSION/bin/istioctl $WORK_DIR/bin/.
mv istio-$ISTIO_VERSION $WORK_DIR/
## Install kubectx
curl -sLO https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx
chmod +x kubectx
mv kubectx $WORK_DIR/bin
# Install Kops
curl -sLO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
mv kops-linux-amd64 $WORK_DIR/bin/kops
# Install nomos
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos nomos
chmod +x nomos
mv nomos $WORK_DIR/bin


#Install Anthos CLI and Components
sudo gcloud components install kpt anthoscli alpha --quiet
sudo gcloud components update --quiet
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

# Rename GKE Cluster Context
kubectx central=gke_${PROJECT_ID}_${CLUSTER_LOCATION}

# Setup onprem GCE Cluster
connect-hub/provision-remote-gce.sh

# Add onprem Cluster to hub
connect-hub/connect-hub.sh

#Install Istio on onprem cluster
# hybrid-multicluster/istio-install-single.sh


# 1.  Setup remote cluster
# 2.  Enable Istio on remote cluster
# 3.  Enable and create Config Mgmt and Repo
# 4.  Enable Cloud Run
# 5.  Automate kpt responses
