# https://github.com/puphpet/vagrant-puppet-lamp
# https://github.com/vagrantee/vagrantee
# https://github.com/miccheng/vagrant-lamp-centos63
# https://github.com/iJoyCode/vagrant-puppet-centos-php-apache
# https://github.com/pipe-devnull/vagrant-dev-lamp

stage { setup: before => Stage[main] }

Exec {
    path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ]
}

File {
	mode => '0644'
}

class proxy {
	$proxy_username = 't31291157816'
	$proxy_domain = 'DASA'
	$proxy_password = '7187A15D1382A8D03C856613F5A554FE'
	$proxy_url = 'proxy-sp.dasa.net'
	$proxy_port = '3128'
	$proxy_no_proxy = 'localhost, 127.0.0.*, 10.*, 192.168.*, *.dasa.com.br, *.dasa.net, 172.*'
	$proxy_listen = '3128'	
	$proxys = ["proxy=http://${proxy_url}:${proxy_port}","proxy=ftp://${proxy_url}:${proxy_port}","proxy=https://${proxy_url}:${proxy_port}"]	
	$config_proxys = ['yum.conf', 'wgetrc']

	define applyproxy() {
		file {$name:
			owner   => "root",
			group   => "root",
			mode => '0644',
			ensure => present,
			replace => true,
			path => "/etc/${name}",
			source => "/vagrant/files/${name}"
		}

		notify {"Aplicando configuração de proxy em ${name}":}
	}
	
	exec {'install-cntlm':
		command => 'rpm -Uvh /vagrant/files/cntlm-*.rpm',
		creates => "/etc/cntlm.conf"
	}
	
	file { '/etc/cntlm.conf':
		mode => '0644',
		owner   => "root",
		group   => "root",
		ensure => present,
		replace => true,
		require => Exec['install-cntlm'],
		notify => Service['cntlmd'],
		content => template("/vagrant/templates/cntlm/cntlm.conf.erb")
	}
	
	service { 'cntlmd':
		ensure => 'running'
	}
	
	applyproxy {$config_proxys: }	
	
	file { "/etc/profile.d/env_proxy.sh":
		content => "export http_proxy=http://${proxy_url}:${proxy_port} https_proxy=http://${proxy_url}:${proxy_port} ftp_proxy=http://${proxy_url}:${proxy_port} HTTP_PROXY_REQUEST_FULLURI=0 HTTPS_PROXY_REQUEST_FULLURI=0"
	}
}

class iptables {
	package { "iptables":
		ensure => present
	}

	service { "iptables":
		require => Package["iptables"],
		hasstatus => true,
		status => "true",
		hasrestart => false,
	}

	file { "/etc/sysconfig/iptables":
		owner   => "root",
		group   => "root",
		mode    => 600,
		replace => true,
		ensure  => present,
		source  => "/vagrant/files/iptables.txt",
		require => Package["iptables"],
		notify  => Service["iptables"],
	}
}

class setup {
		
	define yumgroup($ensure = "present", $optional = false) {
	   case $ensure {
		  present,installed: {
			 $pkg_types_arg = $optional ? {
				true => "--setopt=group_package_types=optional,default,mandatory",
				default => ""
			 }
			 exec { "Installing $name yum group":
				command => "yum -y groupinstall $pkg_types_arg $name",
				unless => "yum -y groupinstall $pkg_types_arg $name --downloadonly",
				timeout => 600,
			 }
		  }
	   }
	}
	
	# include iptables
	
	exec { 'yum-update':
		command => '/usr/bin/yum -y update',
		require => Class["epel"],
		timeout => 600,
		tries   => 3
	}
	
	class { 'epel': }
	
	yumgroup { ['"Development tools"', '"Development Libraries"']:
		require => Exec['yum-update']
	}
	
	package {['vim-enhanced', 'vim-common', 'vim-minimal', 'telnet','zip','unzip','git','nodejs','npm','upstart', 'zlib-devel', 'lynx', 'ftp']:
		ensure => latest,
		require => Exec['yum-update']
	}
	
	include sendmail
	include iptables
}

class install_apache {
	include apache
	
	apache::dotconf { 'custom':
	  content => 'EnableSendfile Off',
	}
	
	#apache::vhost { 'apoio.alvaro.dev':
	#	source      => '/vagrant/files/apoio.alvaro.dev.conf',
	#	template    => ''
	#}
	
}

class install_php {
	include php
	
	php::module{
		[
			'bcmath', 
			'cli', 
			'common',
			'devel',
			'dba',
			'fpm',
			'gd',
			'imap',
			'intl',
			'ldap',
			'mbstring',
			'mcrypt',
			'mssql',
			'mysqlnd',
			'pdo',
			'pgsql',
			'process',
			'pspell',
			'recode',
			'snmp',
			'soap',
			'xml',
			'xmlrpc',
			'pecl-mysqlnd-ms',
			'pecl-mysqlnd-qc',
			'pecl-pthreads',
			'pecl-rar',
			'pecl-solr',
			'pecl-sphinx',
			'pecl-uploadprogress',
			'pecl-uuid',
			'pecl-zendopcache',
			'pecl-memcache',
			'pecl-xdebug',
			'pecl-apc',
			'pecl-imagick',
			'pecl-xhprof'		
		]:
	}
		
	file { "/var/www/html/phpinfo.php":
		owner   => "root",
		group   => "root",
		mode    => 644,
		replace => true,
		ensure  => present,
		content => '<?php phpinfo(); ?>',
		require => Package["php"]
	}
	
	class { 'php::pear':
	  require => Class['php'],
	}
	  
	# Set development values to our php.ini and xdebug.ini
	augeas { 'set-php-ini-values':
		context => '/files/etc/php.ini',
		changes => [
			'set PHP/error_reporting -1',
			'set PHP/display_errors On',
			'set PHP/display_startup_errors On',
			'set PHP/html_errors On',
			'set PHP/short_open_tag On',
			'set Date/date.timezone America/Sao_Paulo'
		],
		require => Package['php'],
		notify  => Service['httpd']
	}
	
	# Instalação e configuração do pear
	php::pear::config { http_proxy: value => "localhost:3128" }
	php::pear::config { auto_discover: value => "1" }
	
	exec { '/usr/bin/pear upgrade pear':
		require => [
			Package['php-pear'],
			Exec['pear-config-set-http_proxy']
		],
	}
	
	# Atualiza os repositórios pear
	define discoverPearChannel {
		exec { "/usr/bin/pear channel-discover $name":
			onlyif => "/usr/bin/pear channel-info $name | grep \"Unknown channel\"",
			require => Exec['/usr/bin/pear upgrade pear']
		}
	}
	
	discoverPearChannel { 'pear.phpunit.de': }	
	discoverPearChannel { 'pecl.php.net': }
	discoverPearChannel { 'components.ez.no': }
	discoverPearChannel { 'pear.symfony-project.com': }
	discoverPearChannel { 'pear.symfony.com': }
	discoverPearChannel { 'pear.phpqatools.org': }
	
	# PHP QA Tools
	exec { 'install_phpqatools':
		command => '/usr/bin/pear install --alldeps pear.phpqatools.org/phpqatools',
		unless => 'pear list -a | grep phpqatools',
		require => [
			Exec['/usr/bin/pear upgrade pear'],
			Php::Pear::Config['auto_discover'],
			DiscoverPearChannel['pear.phpqatools.org']
		]
	}
	
	# Xdebug
	file { '/etc/php.d/xdebug.ini':
		source => '/vagrant/files/xdebug.ini',
		notify  => Service['httpd'],
		require => Package['php-pecl-xdebug']
	}
	
}

class install_mysql {
	class { 'mysql': root_password => '123456'}
	
	#mysql::grant { 'default_db':
	#	mysql_privileges     => 'ALL',
	#	mysql_db             => $mysql_db,
	#	mysql_user           => $mysql_user,
	#	mysql_password       => $mysql_pass,
	#	mysql_host           => $mysql_host,
	#	mysql_grant_filepath => '/home/vagrant/puppet-mysql',
	# }

	# package {'phpmyadmin': require => Class['mysql']}
	
	#apache::vhost { 'phpmyadmin':
	#	server_name => false,
	#	docroot     => '/usr/share/phpmyadmin',
	#	port        => $pma_port,
	#	priority    => '10',
	#	require     => Package['phpmyadmin'],
	#	template    => 'vagrantee/apache/vhost.conf.erb',
	# }
	
	#file { "/etc/httpd/conf.d/phpMyAdmin.conf":
	#	replace => true,
	#	ensure  => present,
	#	source  => "/vagrant/files/httpd/conf.d/phpMyAdmin.conf",
	#}

	#file { "/etc/phpMyAdmin/config.inc.php":
	#	replace => true,
	#	ensure  => present,
	#	source  => "/vagrant/files/phpmy_admin_config.inc.php",
	#	require => Package["phpMyAdmin"]
	#}
}

# Força a execução do cntlm antes de todos as outras tarefas
class {'proxy': stage => setup }

include setup

class { 'install_apache' : require => Class['setup']}
class { 'install_php' : require => Class['setup']}
