#!/bin/bash
######################################
# Prepare the VM host
######################################
sudo apt update -y && sudo apt upgrade -y && \
sudo apt install -y zsh git curl wget whois

curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/variables.sh -o /.variables.sh && \
echo "source /.variables.sh" >> ~/.bashrc && source ~/.bashrc

######################################
# libvirt setup
######################################
sudo lscpu

sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst libosinfo-bin \
libguestfs-tools cpu-checker virt-manager

sudo usermod -aG libvirt-qemu $ADMIN_USER && \
sudo usermod -aG kvm $ADMIN_USER

exec sudo su -l $USER

ip a | grep en # find the name of your NIC

sudo tee -a /etc/systemd/network/10-br0.netdev <<EOF
[NetDev]
Name=br0
Kind=bridge
EOF

sudo tee -a /etc/systemd/network/10-br0.network <<EOF
[Match]
Name=br0

[Network]
DHCP=ipv4
EOF

sudo tee -a /etc/systemd/network/10-eno1.network <<EOF
[Match]
Name=eno1

[Network]
Bridge=br0
EOF

sudo systemctl restart systemd-networkd

sudo tee -a /root/bridged.xml <<EOF
<network>
  <name>br0</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF

sudo virsh net-define --file /root/bridged.xml

sudo virsh net-list --all # validate

sudo virsh net-autostart br0

sudo mkdir /etc/qemu/

sudo tee /etc/qemu/bridge.conf <<EOF
allow br0
EOF

sudo chown root:kvm /etc/qemu/bridge.conf && \
sudo chmod 0660 /etc/qemu/bridge.conf && \
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper && \
sudo systemctl restart libvirtd

sudo mkdir -p /vms/isos && \
sudo chmod 770 -R /vms && \
sudo chown -R libvirt-qemu:kvm /vms && \
sudo chmod g+s /vms

curl https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -o /vms/isos/jammy-server-cloudimg-amd64.img

sudo reboot

######################################
# Networking
######################################
sudo cp /etc/hosts /etc/hosts.bak
sudo tee -a /etc/hosts <<EOF
$STORAGE_SERVER_IP $STORAGE_SERVER_FQDN $STORAGE_SERVER_HOSTNAME
$MANAGEMENT_SERVER_IP $MANAGEMENT_SERVER_FQDN $MANAGEMENT_SERVER_HOSTNAME
$LOGIN_SERVER_IP $LOGIN_SERVER_FQDN $LOGIN_SERVER_HOSTNAME
$WORKER_SERVER_IP $WORKER_SERVER_FQDN $WORKER_SERVER_HOSTNAME
$HEAD_SERVER_IP $HEAD_SERVER_FQDN $HEAD_SERVER_HOSTNAME
EOF

######################################
# Organizational SSH Key Setup
######################################
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 && \
SSH_KEY_CONTENT=$(cat ~/.ssh/id_ed25519.pub | cut -d' ' -f 1-2) && \
echo export SSH_PUBLIC_KEY_ORG=\"$SSH_KEY_CONTENT\" >> /.variables.sh && \
source ~/.bashrc 

# Any servers not created by this script will need to have the org key added to their authorized_keys file!
echo -e "\n$SSH_PUBLIC_KEY_ORG" >> ~/.ssh/authorized_keys

######################################
# Intall the Management VM
######################################
mkdir /vms/$MANAGEMENT_SERVER_HOSTNAME && \
cd /vms/$MANAGEMENT_SERVER_HOSTNAME

tee meta-data.yaml <<EOF
instance-id: $MANAGEMENT_SERVER_HOSTNAME
local-hostname: $MANAGEMENT_SERVER_HOSTNAME
EOF

tee user-data.yaml <<EOF
#cloud-config

users:
  - name: $ADMIN_USER
    shell: /bin/bash
    lock_passwd: false
    groups: sudo
    sudo:  ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $SSH_PUBLIC_KEY_PERSONAL
      - $SSH_PUBLIC_KEY_ORG
EOF

qemu-img create -b /vms/isos/jammy-server-cloudimg-amd64.img -f qcow2 -F qcow2 $MANAGEMENT_SERVER_HOSTNAME-base.img 40G

sudo virt-install \
--name $MANAGEMENT_SERVER_HOSTNAME \
--ram 16384 \
--vcpus 6 \
--import \
--disk path=$MANAGEMENT_SERVER_HOSTNAME-base.img,format=qcow2 \
--os-variant ubuntu22.04 \
--network bridge=br0,model=virtio,mac=$MANAGEMENT_SERVER_MAC \
--graphics vnc,listen=0.0.0.0 --noautoconsole \
--cloud-init user-data=user-data.yaml,meta-data=meta-data.yaml

# wait for the VM to boot and then run the following commands
scp /.variables.sh $ADMIN_USER@$MANAGEMENT_SERVER_HOSTNAME:~/ && \
scp ~/.ssh/id_ed25519 $ADMIN_USER@$MANAGEMENT_SERVER_HOSTNAME:~/.ssh/id_ed25519 && \
scp ~/.ssh/id_ed25519.pub $ADMIN_USER@$MANAGEMENT_SERVER_HOSTNAME:~/.ssh/id_ed25519.pub

######################################
# Delete the Management VM
######################################
# If you're deleting the whole & setup cluster, use ansible to reset the storage server first.
# Re-enter setup at `Organizational SSH Key Setup` following removal of the Management VM

# sudo virsh destroy $MANAGEMENT_SERVER_HOSTNAME && \
# sudo virsh undefine $MANAGEMENT_SERVER_HOSTNAME --remove-all-storage && \
# rm -rf /vms/$MANAGEMENT_SERVER_HOSTNAME && \
# ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R $MANAGEMENT_SERVER_HOSTNAME && \
# sudo sed -i '/^export SSH_PUBLIC_KEY_ORG/d' /.variables.sh && \
# sed -i '/^$SSH_PUBLIC_KEY_ORG' ~/.ssh/authorized_keys && \
# sudo chown $USER:$USER /.variables.sh && \
# rm ~/.ssh/id_ed25519* && \
# source ~/.bashrc

######################################
# Next Steps
######################################
# go to ansible-setup.sh for semi-automated setup of the rest of the cluster
# go to manual-setup.sh for manual setup of the rest of the cluster