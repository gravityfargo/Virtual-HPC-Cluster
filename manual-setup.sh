#!/bin/bash
######################################
# These tasks are to be done manually
# on each VM
######################################

######################################
# Prepare the host
######################################
sudo apt update -y && sudo apt -y upgrade && \
sudo apt install -y zsh git curl wget whois

curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/variables.sh -o ~/variables.sh
chmod 600 /.variables.sh
echo "source /.variables.sh" >> ~/.bashrc && source ~/.bashrc

sudo touch /etc/cloud/cloud-init.disabled

######################################
# Setup Packages
######################################
sudo apt update -y && sudo apt upgrade -y
sudo apt purge -y plymouth modemmanager
sudo apt purge -y snapd
sudo apt-mark hold snapd

sudo apt install -y net-tools nfs-common nmap ufw auditd prometheus-node-exporter \
lua5.3 liblua5.3-dev lua-json lua-lpeg lua-posix lua-filesystem lua-bitop \
tcl tcl-dev uuid tcsh libreadline-dev \
gfortran gnupg2 python3-pip libpmix2

######################################
# Services
######################################

sudo timedatectl set-timezone America/New_York
sudo timedatectl set-ntp true
sudo systemctl enable systemd-timesyncd
sudo systemctl enable prometheus-node-exporter
sudo systemctl enable auditd
sudo systemctl disable fwupd
sudo systemctl disable fwupd-refresh
sudo systemctl disable motd-news

######################################
# Firewall
######################################
sudo ufw allow 9100/tcp comment "prometheus-node-exporter"
sudo ufw allow ssh
sudo ufw allow nfs
sudo ufw enable

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
# SSH Settings
######################################

## V Management Only V
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 && \
SSH_KEY_CONTENT=$(cat ~/.ssh/id_ed25519.pub) && \
echo export SSH_PUBLIC_KEY_MGMT=\"$SSH_KEY_CONTENT\" >> ~/.variables.sh && \
source ~/.bashrc

echo $SSH_PUBLIC_KEY_MGMT >> ~/.ssh/authorized_keys

ssh-keyscan $STORAGE_SERVER_HOSTNAME >> ~/.ssh/known_hosts && \
ssh-keyscan $MANAGEMENT_SERVER_HOSTNAME >> ~/.ssh/known_hosts

ssh-copy-id $STORAGE_SERVER_HOSTNAME
## ^ Management Only ^

sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i '/session[ \t]\+optional[ \t]\+pam_mail.so/s/^/#/' /etc/pam.d/sshd # diable mail message
sudo sed -i 's/#PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config # disable last logged in message
sudo sed -i '/^#ChallengeResponseAuthentication yes/c\ChallengeResponseAuthentication no' /etc/ssh/sshd_config # disable challenge-response authentication
sudo sed -i '/^#PasswordAuthentication yes/c\PasswordAuthentication no' /etc/ssh/sshd_config # disable password logins
sudo sed -i '/^#PermitRootLogin prohibit-password/c\PermitRootLogin no' /etc/ssh/sshd_config # disallow root login entirely
sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl reload ssh

######################################
# MOTD
######################################
sudo rm -rf /etc/update-motd.d/*
sudo curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/assets/motd -o /etc/motd

######################################
# User Shell Customizations
######################################

sudo chsh -s $(which zsh) $USER # change defualt shell to zsh

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

sed -i 's/plugins=(git)/plugins=(zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc # activate plugins

sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="daveverwer"/' ~/.zshrc # change theme
echo "emulate sh -c 'source /etc/profile'" | cat - ~/.zshrc > temp && mv temp ~/.zshrc # login session initialisation - emulated POSIX compatability for zsh

echo "source ~/.variables.sh" >> ~/.bashrc && source ~/.bashrc && \
echo "source ~/.variables.sh" >> ~/.zshrc && source ~/.zshrc

######################################
# Mount Points and environment management 
######################################
sudo mkdir -p /storage/home /storage/projects /storage/software /storage/spack # create nessesary mount points

sudo useradd -m -d /var/lib/slurm -u 1001 -s /bin/bash -U slurm # dedicated slurm user
sudo useradd -m -d /home/swmanager -u 1002 -s /bin/bash -U swmanager
sudo useradd -M -u 1003 filemanager


sudo chown spack:spack /storage/software
sudo chown spack:spack /storage/spack
sudo chown filemanager:filemanager /storage/projects
sudo chown filemanager:filemanager /storage/home

# Storage Server continues in scripts\storage-setup.sh