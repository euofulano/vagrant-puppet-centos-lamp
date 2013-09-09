stage { setup: before => Stage[main] }

Exec {
    path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ]
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
	$config_proxys = ['yum.conf', 'profile', 'wgetrc']

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
	
	service { 'cntlmd':
		ensure => 'running'
	}
	
	applyproxy {$config_proxys:}	
}