#!/bin/bash
######################################
# Prepare the main host
######################################
sudo apt update -y && sudo apt upgrade -y

sudo apt install -y zsh git curl wget whois

curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/variables.sh -o ~/.variables.sh

ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
SSH_KEY_CONTENT=$(cat ~/.ssh/id_ed25519.pub)
echo export SSH_PUBLIC_KEY_STORAGE=\"$SSH_KEY_CONTENT\" >> ~/.variables.sh

echo "source ~/.variables.sh" >> ~/.bashrc && source ~/.bashrc
echo "source ~/.variables.sh" >> ~/.zshrc && source ~/.zshrc

######################################
# libvirt setup
######################################
sudo lscpu
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst libosinfo-bin
sudo apt install libguestfs-tools cpu-checker virt-manager

sudo usermod -aG libvirt-qemu $ADMIN_USER
sudo usermod -aG kvm $ADMIN_USER

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

sudo chown root:kvm /etc/qemu/bridge.conf
sudo chmod 0660 /etc/qemu/bridge.conf
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
sudo systemctl restart libvirtd

sudo mkdir -p /storage/vms/isos
sudo chmod 770 -R /storage/vms
sudo chown -R libvirt-qemu:kvm /storage/vms
sudo chmod g+s /storage/vms

curl https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -o /storage/vms/isos/jammy-server-cloudimg-amd64.img

exit # log out and log back in

######################################
# Networking
######################################
sudo tee -a /etc/hosts <<EOF
$STORAGE_SERVER_IP $STORAGE_SERVER_FQDN $STORAGE_SERVER_HOSTNAME
$MANAGEMENT_SERVER_IP $MANAGEMENT_SERVER_FQDN $MANAGEMENT_SERVER_HOSTNAME
$LOGIN_SERVER_IP $LOGIN_SERVER_FQDN $LOGIN_SERVER_HOSTNAME
$WORKER_SERVER_IP $WORKER_SERVER_FQDN $WORKER_SERVER_HOSTNAME
$HEAD_SERVER_IP $HEAD_SERVER_FQDN $HEAD_SERVER_HOSTNAME
EOF

######################################
# Intall the Management VM
######################################
mkdir /storage/vms/$MANAGEMENT_SERVER_HOSTNAME
cd /storage/vms/$MANAGEMENT_SERVER_HOSTNAME

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
      - $SSH_PUBLIC_KEY_STORAGE
    
EOF

qemu-img create -b /storage/vms/isos/jammy-server-cloudimg-amd64.img -f qcow2 -F qcow2 $MANAGEMENT_SERVER_HOSTNAME-base.img 40G

virt-install \
--name $MANAGEMENT_SERVER_HOSTNAME \
--ram 4096 \
--vcpus 4 \
--import \
--disk path=$MANAGEMENT_SERVER_HOSTNAME-base.img,format=qcow2 \
--os-variant ubuntu22.04 \
--network bridge=br0,model=virtio,mac=$MANAGEMENT_SERVER_MAC \
--graphics vnc,listen=0.0.0.0 --noautoconsole \
--cloud-init user-data=user-data.yaml,meta-data=meta-data.yaml

# virsh destroy $MANAGEMENT_SERVER_HOSTNAME
# virsh undefine $MANAGEMENT_SERVER_HOSTNAME --remove-all-storage
# rm -rf /storage/vms/$MANAGEMENT_SERVER_HOSTNAME
# ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R "$MANAGEMENT_SERVER_HOSTNAME"

# wait for the VM to boot and then run the following commands
scp ~/.variables.sh $ADMIN_USER@$MANAGEMENT_SERVER_HOSTNAME:~/


# go to ansible-setup.sh for semi-automated setup of the rest of the cluster
# go to manual-setup.sh for manual setup of the rest of the cluster