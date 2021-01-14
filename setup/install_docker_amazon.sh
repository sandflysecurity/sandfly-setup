#!/usr/bin/env bash
# Sandfly Security LTD www.sandflysecurity.com
# Copyright (c) 2016-2021 Sandfly Security LTD, All Rights Reserved.

# Install script for Amazon AWS Linux

sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum makecache fast

sudo yum -y install docker

sudo service docker start

