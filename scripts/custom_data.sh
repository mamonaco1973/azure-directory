#!/bin/bash

# Pretty basic custom data script - install apache2 and enable it

sudo apt update -y
sudo apt install apache2 -y
sudo systemctl enable apache2
sudo systemctl start apache2