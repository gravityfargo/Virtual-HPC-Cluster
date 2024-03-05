# Virtual-HPC-Cluster
A comprehensive guide for setting up a virtualized HPC cluster for research, development, and education. Includes setup guides, configurations, and is open for community contributions. 

Assumptions:
- The server recieving this project will act as the storage server, and the vm-host.
- The same administrator account should be used across the cluster, it should match the storage server's account.
- A storage array/disk/partion is mounted to `/storage`

Notes:
- Any VM can be substituted for a physical server. Simply skip the creation that particular VM, and manually add an entry to `/etc/ansible/hosts` (if using ansible setup). Install Ubuntu Server Jammy.
- For simplicity, use `sudo visudo` to enable passwordless sudo. This is insecure and should not be used in production. Make sure ssh password auth is disabled.
- Infiniband can be used. Just have it set up, and use it's subnet in the `/etc/exports` file on the storage host.

Usage - One Physical Server:
- Following "initial-setup.sh", the end of the file will direct you to either manual or ansible setup.