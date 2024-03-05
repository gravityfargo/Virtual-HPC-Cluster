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

######################################
# spack
######################################
sudo su - swmanager
cd /tmp && wget https://github.com/spack/spack/releases/download/v0.21.0/spack-0.21.0.tar.gz
tar -xzvf spack-0.21.0.tar.gz
mv spack-0.21.0/* /storage/spack/
echo "source /storage/spack/share/spack/setup-env.sh" >> ~/.bashrc
source ~/.bashrc
# for other users add them to the swmanager group and add the source line to their .bashrc/.zshrc
vim /storage/spack/etc/spack/config.yaml
# see storage\config.yaml
vim /storage/spack/etc/spack/modules.yaml
# see storage\modules.yaml
# tells lmod where spack installed packages
echo '/storage/sw/modules/linux-ubuntu22.04-x86_64/Core' > /storage/sw/lmod/lmod/init/.modulespath
# example packages install
spack install miniconda3 py-numpy py-tensorflow r-dplyr py-pandas tar
reboot