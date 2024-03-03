#!/bin/bash
######################################
# Prepare the main host
######################################
sudo apt install -y zsh git curl wget whois

curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/variables.sh -o ~/variables.sh

echo "source ~/variables.sh" >> ~/.bashrc && source ~/.bashrc
echo "source ~/variables.sh" >> ~/.zshrc && source ~/.zshrc

sudo mkdir -p /storage/vms/isos
curl https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -o /storage/vms/isos/jammy-server-cloudimg-amd64.img

sudo chown -R libvirt-qemu:kvm -R /storage/vms
sudo usermod -aG kvm $ADMIN_USER
sudo chmod 770 /storage/vms

# logout and back in to apply group changes

######################################
# Intall the Management VM
######################################

mkdir /storage/vms/$MANAGEMENT_SERVER_HOSTNAME
cd /storage/vms/$MANAGEMENT_SERVER_HOSTNAME

tee meta-data.yaml <<EOF
instance-id: $MANAGEMENT_SERVER_HOSTNAME
local-hostname: $MANAGEMENT_SERVER_HOSTNAME
EOF

export ADMIN_PASSWORD_HASH=$(echo $TEMP_ADMIN_PASSWORD | mkpasswd --method=SHA-512 --rounds=4096)

tee user-data.yaml <<EOF
#cloud-config

users:
  - name: $ADMIN_USER
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: sudo, wheel
    ssh_authorized_keys:
      - $SSH_PUBLIC_KEY
    lock_passwd: false
EOF

sudo qemu-img create -b /storage/vms/isos/jammy-server-cloudimg-amd64.img -f qcow2 -F qcow2 $MANAGEMENT_SERVER_HOSTNAME-base.img 40G

sudo virt-install \
--name $MANAGEMENT_SERVER_HOSTNAME \
--ram 4096 \
--vcpus 4 \
--import \
--disk path=$MANAGEMENT_SERVER_HOSTNAME-base.img,format=qcow2 \
--os-variant ubuntu22.04 \
--network bridge=br0,model=virtio,mac=$MANAGEMENT_SERVER_MAC \
--graphics vnc,listen=0.0.0.0 --noautoconsole \
--cloud-init user-data=user-data.yaml,meta-data=meta-data.yaml \
--debug

# go to ansible-setup.sh for semi-automated setup of the rest of the cluster
# go to manual-setup.sh for manual setup of the rest of the cluster