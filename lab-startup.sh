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

# Setup onprem GCE Cluster
connect-hub/provision-remote-gce.sh

# Add onprem Cluster to hub
connect-hub/connect-hub.sh

# Rename GKE Cluster Context
kubectx central=gke_${PROJECT_ID}_${CLUSTER_LOCATION}_central

# Config Management Setup
export PROJECT=$(gcloud config get-value project)
cd $HOME
export GCLOUD_ACCOUNT=$(gcloud config get-value account)
export REPO_URL=https://source.developers.google.com/p/${PROJECT}/r/config-repo

# Setup Repo
git clone https://github.com/cgrant/config-repo config-repo
cd config-repo
git remote remove origin
git config credential.helper gcloud.sh
git remote add origin $REPO_URL

gcloud source repos create config-repo
git push -u origin master

# Install Config management Operator
kubectx central
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml
kubectl apply -f config-management-operator.yaml
kubectx onprem
kubectl apply -f config-management-operator.yaml

# Create Repo SSH Key
ssh-keygen -t rsa -b 4096 \
-C "$GCLOUD_ACCOUNT" \
-N '' \
-f $HOME/.ssh/id_rsa.nomos

# Configure Repo
kubectx central
kubectl create secret generic git-creds \
--namespace=config-management-system \
--from-file=ssh=$HOME/.ssh/id_rsa.nomos

kubectx onprem
kubectl create secret generic git-creds \
--namespace=config-management-system \
--from-file=ssh=$HOME/.ssh/id_rsa.nomos

# Apply Config Management Rexource
export REMOTE=onprem
export CENTRAL=central
REPO_URL=ssh://${GCLOUD_ACCOUNT}@source.developers.google.com:2022/p/${PROJECT}/r/config-repo
kubectx $REMOTE
# Replace variables and stream results to kubectl apply
cat $BASE_DIR/config-management/config_sync.yaml | \
  sed 's|<REPO_URL>|'"$REPO_URL"'|g' | \
  sed 's|<CLUSTER_NAME>|'"$REMOTE"'|g' | \
  sed 's|none|ssh|g' | \
  kubectl apply -f -

  kubectx $CENTRAL
  cat $BASE_DIR/config-management/config_sync.yaml | \
    sed 's|<REPO_URL>|'"$REPO_URL"'|g' | \
    sed 's|<CLUSTER_NAME>|'"$CENTRAL"'|g' | \
    sed 's|none|ssh|g' | \
    kubectl apply -f -
      
# Enable Cloud Run on GKE
gcloud container clusters update central --update-addons=CloudRun=ENABLED,HttpLoadBalancing=ENABLED --zone=us-central1-b


#Install Istio on onprem cluster
# hybrid-multicluster/istio-install-single.sh


# 1.  Setup remote cluster
# 2.  Enable Istio on remote cluster
# 3.  Enable and create Config Mgmt and Repo
# 4.  Enable Cloud Run
# 5.  Automate kpt responses
