sudo apt install -y liblua5.3-dev tcl-dev libreadline-dev nfs-kernel-server bc

sudo tee -a /etc/exports <<EOF
/storage        $SUBNET(rw,sync,no_subtree_check)
EOF

sudo systemctl enable nfs-kernel-server
sudo systemctl start nfs-kernel-server

sudo exportfs -a

######################################
# Lmod
######################################
sudo su - spack
cd /tmp && wget https://github.com/TACC/Lmod/archive/refs/tags/$LMOD_VERSION.tar.gz
tar -xzvf $LMOD_VERSION.gz
cd Lmod-8.7.34
./configure --prefix=/storage/software
make install
sudo ln -s /storage/software/lmod/lmod/init/profile /etc/profile.d/z00_lmod.sh

echo 'MODULEPATH="/storage/software/modules/linux-ubuntu22.04-x86_64/Core"' | sudo tee -a /etc/environment > /dev/null
exit
######################################
# spack
######################################
sudo su - spack
cd /tmp && wget https://github.com/spack/spack/releases/download/v0.21.0/spack-0.21.0.tar.gz
tar -xzvf spack-0.21.0.tar.gz
mv spack-0.21.0/* /storage/spack/
echo "source /storage/spack/share/spack/setup-env.sh" >> ~/.bashrc
source ~/.bashrc

curl ttps://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/assets/spack/config.yaml -o /storage/spack/etc/spack/config.yaml
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/assets/spack/modules.yaml -o /storage/spack/etc/spack/modules.yaml
curl https://raw.githubusercontent.com/gravityfargo/Virtual-HPC-Cluster/main/assets/spack/compilers.yaml -o /storage/spack/etc/spack/compilers.yaml
vim /storage/spack/etc/spack/modules.yaml

echo '/storage/software/modules/linux-ubuntu22.04-x86_64/Core' > /storage/software/lmod/lmod/init/.modulespath
# example packages install
spack install miniconda3 py-numpy py-tensorflow r-dplyr py-pandas tar
reboot