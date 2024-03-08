#!/bin/bash
######################################
# Setup Packages on Management Server
######################################
sudo apt update -y && sudo apt -y upgrade && \
sudo apt install -y zsh git curl wget whois && \
sudo mv ~/.variables.sh /.variables.sh && \
chmod 600 /.variables.sh && \
echo "source /.variables.sh" >> ~/.bashrc && source ~/.bashrc

sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
sudo systemctl restart sshd

sudo touch /etc/cloud/cloud-init.disabled

sudo apt-add-repository ppa:ansible/ansible && \
sudo apt install -y ansible

sudo groupadd -r ansibleadmins && \
sudo usermod -aG ansibleadmins $USER && \
exec sudo su -l $USER

sudo chown -R root:ansibleadmins /etc/ansible && \
sudo chmod 774 /etc/ansible && \
sudo chmod 664 /etc/ansible/hosts

######################################
# Start here if using an existing ansible controller
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
# Prepare Ansible
######################################
tee /etc/ansible/hosts <<EOF
[cluster]
$STORAGE_SERVER_HOSTNAME
$MANAGEMENT_SERVER_HOSTNAME

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 && \
SSH_KEY_CONTENT=$(cat ~/.ssh/id_ed25519.pub) && \
echo export SSH_PUBLIC_KEY_MGMT=\"$SSH_KEY_CONTENT\" >> /.variables.sh && \
source ~/.bashrc

echo $SSH_PUBLIC_KEY_MGMT >> ~/.ssh/authorized_keys

ssh-keyscan $STORAGE_SERVER_HOSTNAME >> ~/.ssh/known_hosts && \
ssh-keyscan $MANAGEMENT_SERVER_HOSTNAME >> ~/.ssh/known_hosts

ssh-copy-id $STORAGE_SERVER_HOSTNAME
# perform the same for any non vm hosts

ansible all -m ping

######################################
# Create nessessary VMs
######################################
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/create-vm.yml -o ~/create-vm.yml

ansible-playbook create-vm.yml -e "hostname=$LOGIN_SERVER_HOSTNAME" \
-e "vm_host='$STORAGE_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" -e "mac=$LOGIN_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_mgmt='$SSH_PUBLIC_KEY_MGMT'" \
-e "ip=$LOGIN_SERVER_IP"

ansible-playbook create-vm.yml -e "hostname=$HEAD_SERVER_HOSTNAME" \
-e "vm_host='$STORAGE_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" -e "mac=$HEAD_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_mgmt='$SSH_PUBLIC_KEY_MGMT'" \
-e "ip=$HEAD_SERVER_IP"

# ansible-playbook create-vm.yml -e "hostname=$WORKER_SERVER_HOSTNAME" \
# -e "vm_host='$WORKER_SERVER_HOSTNAME'" \
# -e "admin_user=$ADMIN_USER" -e "mac=$WORKER_SERVER_MAC" \
# -e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
# -e "ssh_public_key_mgmt='$SSH_PUBLIC_KEY_MGMT'" \
# -e "ip=$WORKER_SERVER_IP"

######################################
# Delete VMs
######################################

curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/delete-vm.yml -o ~/delete-vm.yml
# ansible-playbook delete-vm.yml -e "vm_host=$STORAGE_SERVER_HOSTNAME" -e "target_hostname=$LOGIN_SERVER_HOSTNAME"
# ansible-playbook delete-vm.yml -e "vm_host=$STORAGE_SERVER_HOSTNAME" -e "target_hostname=$HEAD_SERVER_HOSTNAME"

######################################
# Prepare the base OSes
######################################
# do not use the "all" as host until after running these commands for the first time.
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/prepare-base-os.yml -o ~/prepare-base-os.yml

ansible-playbook prepare-base-os.yml -e "target_hostname=$MANAGEMENT_SERVER_HOSTNAME" -e "admin_user=$ADMIN_USER"
ansible-playbook prepare-base-os.yml -e "target_hostname=$STORAGE_SERVER_HOSTNAME" -e "admin_user=$ADMIN_USER"
ansible-playbook prepare-base-os.yml -e "target_hostname=$LOGIN_SERVER_HOSTNAME" -e "admin_user=$ADMIN_USER"
ansible-playbook prepare-base-os.yml -e "target_hostname=$HEAD_SERVER_HOSTNAME" -e "admin_user=$ADMIN_USER"
ansible-playbook prepare-base-os.yml -e "target_hostname=$WORKER_SERVER_HOSTNAME" -e "admin_user=$ADMIN_USER"

######################################
# Prepare the Storage Server
######################################
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/prepare-storage-server.yml -o ~/prepare-storage-server.yml

ansible-playbook prepare-storage-server.yml \
-e "storage_server_hostname=$STORAGE_SERVER_HOSTNAME" \
-e "subnet=$SUBNET" \
-e "lmod_version=$LMOD_VERSION" \
-e "admin_user=$ADMIN_USER"

# ansible-playbook undo-storage.yml \
# -e "storage_server_hostname=$STORAGE_SERVER_HOSTNAME" \
# -e "subnet=$SUBNET"

######################################
# Prepare the Login, Worker, and Head Servers
######################################
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/prepare-hpc-clients.yml -o ~/prepare-hpc-clients.yml

ansible-playbook prepare-hpc-clients.yml \
-e target_hostname=$LOGIN_SERVER_HOSTNAME \
-e "storage_server_hostname=$STORAGE_SERVER_HOSTNAME" \
-e "admin_user=$ADMIN_USER"