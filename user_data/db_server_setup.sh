#!/bin/bash
yum update -y
amazon-linux-extras install postgresql14 -y
yum install -y postgresql-server
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql