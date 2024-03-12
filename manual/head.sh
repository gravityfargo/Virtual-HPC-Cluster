#!/bin/bash
sudo apt install libmunge-dev libmunge2 munge
sudo systemctl enable munge
apt install libmunge-dev libmunge2 munge
systemctl enable munge
systemctl edit munge --full
# modify to `ExecStart=/usr/sbin/munged --num-threads=10`
systemctl daemon-reload
systemctl start munge