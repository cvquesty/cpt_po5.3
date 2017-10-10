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
  #####                            #####
  ## Configure Directory Environments ##
  #####                            #####

ini_setting { 'Master Agent Server':
  section => 'agent',
  setting => 'server',
  value   => 'master.puppet.vm',
}

ini_setting { 'Master Agent Certname':
  section  => 'agent',
  setting  => 'certname',
  value    => 'master.puppet.vm',
}
EOF

# Install and Configure PuppetDB
/opt/puppetlabs/puppet/bin/puppet module install puppetlabs-puppetdb
/opt/puppetlabs/puppet/bin/puppet apply -e "include puppetdb" --http_connect_timeout=5m || true
/opt/puppetlabs/puppet/bin/puppet apply -e "include puppetdb::master::config" --http_connect_timeout=5m || true

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

# Place the directory environments config file
cat > /var/tmp/configure_directory_environments.pp << 'EOF'
#####                            #####
## Configure Directory Environments ##
#####                            #####

# Default for ini_setting resources:
Ini_setting {
  ensure => 'present',
  path   => "${::settings::confdir}/puppet.conf",
}

ini_setting { 'Configure Environmentpath':
  section => 'main',
  setting => 'environmentpath',
  value   => '$codedir/environments',
}

ini_setting { 'Configure Basemoudlepath':
  section => 'main',
  setting => 'basemodulepath',
  value   => '$confdir/modules:/opt/puppetlabs/puppet/modules',
}

ini_setting { 'Master Agent Server':
  section => 'agent',
  setting => 'server',
  value   => 'master.puppet.vm',
}

ini_setting { 'Master Agent Certname':
  section => 'agent',
  setting => 'certname',
  value   => 'master.puppet.vm',
}
EOF

# Install Zack-r10k to configure r10k
/opt/puppetlabs/puppet/bin/puppet module install puppet-r10k

# Now Apply Subsystem Configurations
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_r10k.pp
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_directory_environments.pp

# Install and Configure autosign.conf for agents
cat > /etc/puppetlabs/puppet/autosign.conf << 'EOF'
*.puppet.vm
EOF

# Turn off and disable the Firewall
/usr/bin/systemctl disable iptables.service
/usr/bin/systemctl stop iptables.service

# Initial r10k Deploy
/usr/bin/r10k deploy environment -pv

# Bounce the network to trade out the Virtualbox IP
/usr/bin/systemctl restart network

# Do initial Puppet Run
  /opt/puppetlabs/puppet/bin/puppet agent -t
