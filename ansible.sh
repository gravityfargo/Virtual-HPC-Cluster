#!/bin/bash
######################################
# Prepare the management server
######################################
# this file is meant to be run on the management server immediately after it is created

sudo apt install -y zsh git curl wget whois

curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/variables.sh -o ~/variables.sh

echo "source ~/variables.sh" >> ~/.bashrc && source ~/.bashrc
echo "source ~/variables.sh" >> ~/.zshrc && source ~/.zshrc

sudo touch /etc/cloud/cloud-init.disabled # disable cloud-init

sudo apt-add-repository ppa:ansible/ansible
sudo apt update && sudo apt upgrade -y 

sudo apt install -y ansible
sudo mkdir -p /etc/ansible

sudo groupadd ansibleadmins
sudo usermod -aG ansibleadmins $ADMIN_USER

sudo chown root:ansibleadmins /etc/ansible
sudo chmod 770 /etc/ansible
sudo chmod 664 /etc/ansible/hosts

# log user out and back in to apply group changes

######################################
# Prepare Ansible
######################################

sudo tee /etc/ansible/hosts <<EOF
[cluster]
$STORAGE_SERVER_HOSTNAME ansible_host=$STORAGE_SERVER_IP
$MANAGEMENT_SERVER_HOSTNAME ansible_host=localhost
# $LOGIN_SERVER_HOSTNAME ansible_host=$LOGIN_SERVER_IP
# $WORKER_SERVER_HOSTNAME ansible_host=$WORKER_SERVER_IP
# $HEAD_SERVER_HOSTNAME ansible_host=$HEAD_SERVER_IP

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

sudo tee -a /etc/hosts <<EOF
$STORAGE_SERVER_IP $STORAGE_SERVER_FQDN $STORAGE_SERVER_HOSTNAME
$MANAGEMENT_SERVER_IP $MANAGEMENT_SERVER_FQDN $MANAGEMENT_SERVER_HOSTNAME
$LOGIN_SERVER_IP $LOGIN_SERVER_FQDN $LOGIN_SERVER_HOSTNAME
$WORKER_SERVER_IP $WORKER_SERVER_FQDN $WORKER_SERVER_HOSTNAME
$HEAD_SERVER_IP $HEAD_SERVER_FQDN $HEAD_SERVER_HOSTNAME
EOF

ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
SSH_KEY_CONTENT=$(cat ~/.ssh/id_ed25519.pub)
sed -i "s|SSH_PUBLIC_KEY_MGMT=\"\"|SSH_PUBLIC_KEY_MGMT=\"$SSH_KEY_CONTENT\"|g" ~/variables.sh

ssh-copy-id $ADMIN_USER@$STORAGE_SERVER_FQDN

######################################
# Create nessessary VMs
######################################
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/create-vm.yml -o ~/create-vm.yml

ansible-playbook --ask-become-pass create-vm.yml -e "hostname=$LOGIN_SERVER_HOSTNAME" \
-e "vm_host='$STORAGE_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" -e "mac=$LOGIN_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_mgmt='$SSH_PUBLIC_KEY_MGMT'" \
-e "ip=$LOGIN_SERVER_IP"

ansible-playbook --ask-become-pass create-vm.yml -e "hostname=$HEAD_SERVER_HOSTNAME" \
-e "vm_host='$STORAGE_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" -e "mac=$HEAD_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_mgmt='$SSH_PUBLIC_KEY_MGMT'" \
-e "ip=$HEAD_SERVER_IP"

# curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/delete-vm.yml -o ~/delete-vm.yml
# ansible-playbook --ask-become-pass delete-vm.yml -e "vm_host=$STORAGE_SERVER_HOSTNAME" -e "target_hostname=$LOGIN_SERVER_HOSTNAME"
