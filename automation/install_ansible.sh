#! /bin/bash
sudo apt-get update
sudo apt install software-properties-common -y
sudo add-apt-repository --yes ppa:ansible/ansible
sudo apt-get update
sudo apt install ansible -y
