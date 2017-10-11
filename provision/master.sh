#!/bin/bash

# Clean the yum cache
rm -fr /var/cache/yum/*
/usr/bin/yum clean all

# Install Puppet Labs Official Repository for CentOS 7
/bin/rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm

# Install Puppet Server Components and Support Packages
/usr/bin/yum -y install puppetserver

# Start and Enable the Puppet Master
/usr/bin/systemctl start puppetserver
/usr/bin/systemctl enable puppetserver

# Install Git
/usr/bin/yum -y install git

# Configure the Puppet Master
cat > /var/tmp/configure_puppet_master.pp << EOF
  #####                   #####
  ## Configure Puppet Master ##
  #####                   #####

cat >>/etc/puppetlabs/puppet/puppet.conf << EOF
[agent]
server=master.puppet.vm
certname=master.puppet.vm
EOF

# Bounce the network to trade out the Virtualbox IP
/usr/bin/systemctl restart network

# Turn off the Firewall for this infrastructure
/usr/bin/systemctl stop firewalld
/usr/bin/systemctl disable firewalld

# Do initial Puppet Run
/opt/puppetlabs/puppet/bin/puppet agent -t --server=master.puppet.vm

# Place the r10k configuration file
cat > /var/tmp/configure_r10k.pp << 'EOF'
class { 'r10k':
  version => '2.5.5',
  sources => {
    'puppet' => {
      'remote'  => 'https://github.com/cvquesty/h5_control.git',
      'basedir' => "${::settings::codedir}/environments",
      'prefix'  => false,
    }
  },
  manage_modulepath => false,
}
EOF

# Install Puppet-r10k to configure r10k and all Dependencies
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-r10k
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-make
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-concat
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-stdlib
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-ruby
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-gcc
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-make
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-inifile
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-vcsrepo
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-pe_gem
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-git
/opt/puppetlabs/puppet/bin/puppet module install -f gentoo-portage

# Now Apply Subsystem Configuration
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_r10k.pp

# Install and Configure autosign.conf for agents
cat > /etc/puppetlabs/puppet/autosign.conf << 'EOF'
*.puppet.vm
EOF

# Initial r10k Deploy
/usr/bin/r10k deploy environment -pv
