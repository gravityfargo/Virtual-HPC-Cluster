sudo apt install -y liblua5.3-dev tcl-dev libreadline-dev nfs-kernel-server bc

sudo tee -a /etc/exports <<EOF
/storage        $SUBNET(rw,sync,no_subtree_check)
/storage/projects   $SUBNET(rw,sync,no_subtree_check)
/storage/home   $SUBNET(rw,sync,no_subtree_check)
/storage/sw $SUBNET(rw,sync,no_subtree_check)
/storage/spack  $SUBNET(rw,sync,no_subtree_check)
EOF

sudo systemctl enable nfs-kernel-server
sudo systemctl start nfs-kernel-server

sudo exportfs -a

######################################
# Lmod
######################################
sudo su - swmanager
cd /tmp && wget https://github.com/TACC/Lmod/archive/refs/tags/8.7.34.tar.gz
tar -xzvf 8.7.34.tar.gz
cd Lmod-8.7.34
./configure --prefix=/storage/sw
make install
sudo ln -s /storage/sw/lmod/lmod/init/profile /etc/profile.d/z00_lmod.sh

echo 'MODULEPATH="/storage/sw/modules/linux-ubuntu22.04-x86_64/Core"' | sudo tee -a /etc/environment > /dev/null
exit
module purge
clearMT
unset MODULEPATH
module use /storage/sw/modules/linux-ubuntu22.04-x86_64/Core