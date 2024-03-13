#!/bin/bash
######################################
# Setup Packages on Management Server
######################################
sudo apt update -y && sudo apt -y upgrade && \
sudo apt install -y zsh git curl wget whois && \
sudo mv ~/.variables.sh /.variables.sh && \
chmod 600 /.variables.sh && \
echo "source /.variables.sh" >> ~/.bashrc && source ~/.bashrc

# Reboot from vm host. If there was a kernel update, reboot fails so start and stop as below.
# sudo virsh shutdown $MANAGEMENT_SERVER_HOSTNAME && sleep 10 && sudo virsh start $MANAGEMENT_SERVER_HOSTNAME

sudo touch /etc/cloud/cloud-init.disabled

sudo apt-add-repository ppa:ansible/ansible && \
sudo apt install -y ansible

sudo groupadd -r ansibleadmins && \
sudo usermod -aG ansibleadmins $USER && \
exec sudo su -l $USER


######################################
# Start here if using an existing ansible controller
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
# Prepare Ansible
######################################
sudo tee /etc/ansible/hosts <<EOF
[management]
$MANAGEMENT_SERVER_HOSTNAME ansible_user=$ADMIN_USER

[login]
$LOGIN_SERVER_HOSTNAME ansible_user=$ADMIN_USER

[storage]
$STORAGE_SERVER_HOSTNAME ansible_user=$ADMIN_USER

[head]
$HEAD_SERVER_HOSTNAME ansible_user=$ADMIN_USER

[workers]
$WORKER_SERVER_HOSTNAME ansible_user=$ADMIN_USER

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF


sudo chown -R root:ansibleadmins /etc/ansible && \
sudo chmod 774 /etc/ansible && \
sudo chmod 664 /etc/ansible/hosts


cd && git clone https://github.com/gravityfargo/Virtual-HPC-Cluster.git && \
cd Virtual-HPC-Cluster

######################################
# Create nessessary VMs
######################################
ansible-playbook playbooks/create-vm.yml -e "hostname=$LOGIN_SERVER_HOSTNAME" \
-e "vm_host='$STORAGE_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" \
-e "mac=$LOGIN_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_org='$SSH_PUBLIC_KEY_ORG'" \
-e "ip=$LOGIN_SERVER_IP"

ansible-playbook playbooks/create-vm.yml -e "hostname=$HEAD_SERVER_HOSTNAME" \
-e "vm_host='$STORAGE_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" -e "mac=$HEAD_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_org='$SSH_PUBLIC_KEY_ORG'" \
-e "ip=$HEAD_SERVER_IP"

ansible-playbook playbooks/create-vm.yml -e "hostname=$WORKER_SERVER_HOSTNAME" \
-e "vm_host='$WORKER_SERVER_HOSTNAME'" \
-e "admin_user=$ADMIN_USER" -e "mac=$WORKER_SERVER_MAC" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'" \
-e "ssh_public_key_org='$SSH_PUBLIC_KEY_ORG'" \
-e "ip=$WORKER_SERVER_IP"

# ansible all -m ping

ansible-playbook playbooks/keyscan.yml \
-e "target=localhost"

######################################
# Prepare the base OSes
######################################
ansible-playbook playbooks/prepare-base-os.yml -e "admin_user=$ADMIN_USER"

######################################
# Prepare the Storage Server
######################################
ansible-playbook playbooks/prepare-storage-server.yml \
-e "subnet=$SUBNET" \
-e "lmod_version=$LMOD_VERSION" \
-e "admin_user=$ADMIN_USER"

######################################
# Prepare the HPC Clients
######################################
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/prepare-hpc-cluster.yml -o ~/prepare-hpc-cluster.yml

ansible-playbook playbooks/prepare-hpc-cluster.yml \
-e "storage_server_hostname=$STORAGE_SERVER_HOSTNAME" \
-e "admin_user=$ADMIN_USER"

######################################
# Prepare the Head Server
######################################
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/playbooks/prepare-head.yml -o ~/prepare-head.yml

ansible-playbook playbooks/keyscan.yml \
-e "target=$HEAD_SERVER_HOSTNAME"

ansible-playbook playbooks/prepare-head.yml

######################################
# Reset a Server
######################################
ansible-playbook playbooks/reset.yml \
-e "target_hostname=$STORAGE_SERVER_HOSTNAME" \
-e "storage_server_hostname=$STORAGE_SERVER_HOSTNAME" \
-e "subnet=$SUBNET" \
-e "admin_user=$ADMIN_USER" \
-e "ssh_public_key_personal='$SSH_PUBLIC_KEY_PERSONAL'"

######################################
# Delete a VM
######################################
# If deleting the whole cluster, reset the storage server first.

ansible-playbook playbooks/delete-vm.yml \
-e "vm_host=$STORAGE_SERVER_HOSTNAME" \
-e "target_hostname=$LOGIN_SERVER_HOSTNAME"

ansible-playbook playbooks/delete-vm.yml \
-e "vm_host=$STORAGE_SERVER_HOSTNAME" \
-e "target_hostname=$HEAD_SERVER_HOSTNAME"

ansible-playbook playbooks/delete-vm.yml \
-e "vm_host=$STORAGE_SERVER_HOSTNAME" \
-e "target_hostname=$WORKER_SERVER_HOSTNAME"