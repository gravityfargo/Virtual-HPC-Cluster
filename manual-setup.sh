#!/bin/bash
######################################
# These tasks are to be done manually
# on each VM
######################################

######################################
# Clean the base system
######################################
sudo apt update -y && sudo apt upgrade -y
# remove snapd
sudo apt purge -y snapd
sudo apt-mark hold snapd

# remove unwanted packages
sudo apt purge -y plymouth modemmanager
 # install some common packages
sudo apt install -y net-tools zsh nfs-common nmap git ufw auditd prometheus-node-exporter

# Time sync settings, requred for MUNGE
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-ntp true

######################################
# Convenience Customizations
######################################
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc # activate plugins
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="daveverwer"/' ~/.zshrc # change theme
echo "emulate sh -c 'source /etc/profile'" | cat - ~/.zshrc > temp && mv temp ~/.zshrc # login session initialisation - emulated POSIX compatability for zsh
sudo chsh -s $(which zsh) $USER # change defualt shell
source ~/.zshrc # activate the changes

######################################
# Customizations
######################################
# remove stock MOTD
sudo sed -i '/session[ \t]\+optional[ \t]\+pam_mail.so/s/^/#/' /etc/pam.d/sshd # diable mail message
sudo sed -i 's/#PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config # disable last logged in message
sudo rm -rf /etc/update-motd.d/* # remove stock dynamic motds
sudo touch /etc/motd
# insert assets\motd

######################################
# Services
######################################
sudo systemctl disable fwupd # Disable unnecessary service
sudo systemctl disable fwupd-refresh # Disable unnecessary service
sudo systemctl disable motd-news # Disable unnecessary service
sudo systemctl enable systemd-timesyncd
sudo systemctl enable prometheus-node-exporter
sudo systemctl enable auditd
sudo ufw enable

######################################
# Firewall
######################################
sudo ufw allow 9100/tcp comment "prometheus-node-exporter"
sudo ufw allow ssh
sudo ufw allow nfs