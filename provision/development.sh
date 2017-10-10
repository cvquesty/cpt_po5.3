#!/bin/bash

# Turn off the Firewall and Disable it
/bin/systemctl stop firewalld
/bin/systemctl disable firewalld
/bin/systemctl stop iptables
/bin/systemctl disable iptables

# Install Puppet Labs Official Repository for CentOS 7
  /bin/rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm

# Install Puppet Server Components and Support Packages
/usr/bin/yum -y install puppet-agent

# Restart Networking to Pick Up New IP
/bin/systemctl restart network

# Create a puppet.conf
cat >> /etc/puppetlabs/puppet/puppet.conf << 'EOF'
certname = development.puppet.vm
server = master.puppet.vm
EOF

# Do initial Puppet Run
/opt/puppetlabs/puppet/bin/puppet agent -t
