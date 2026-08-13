# nginx TLS termination in front of Mattermost, certificates from Let's
# Encrypt via certbot (webroot).
#
# Bootstraps in two applies, on purpose:
#   1st: no certificate on disk yet -> HTTP-only vhost serving the ACME
#        webroot, then certbot obtains the certificate.
#   2nd: certificate exists -> full HTTPS vhost, HTTP reduced to
#        ACME + redirect.
# Masterless apply evaluates find_file() on this host, which is what makes
# the phase detection work. The puppet-apply timer performs the second
# phase automatically if you don't.
#
# @param letsencrypt_email Registration/expiry contact for Let's Encrypt.
class profile::nginx (
  String[1] $letsencrypt_email,
) {
  # Single source of truth: the certificate domain comes from the SiteURL
  # the mattermost module is configured with.
  $server_name = regsubst(lookup('mattermost::site_url'), '^https?://([^/]+).*$', '\1')
  $has_cert    = find_file("/etc/letsencrypt/live/${server_name}/fullchain.pem") =~ NotUndef

  package { ['nginx', 'certbot']:
    ensure  => installed,
    require => Package['epel-release'],
  }

  # nginx runs in httpd_t, which may not initiate network connections —
  # required for proxying to 127.0.0.1:8065 with SELinux enforcing.
  selboolean { 'httpd_can_network_connect':
    value      => 'on',
    persistent => true,
  }

  file { ['/var/www', '/var/www/letsencrypt']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/nginx/conf.d/mattermost.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/mattermost-nginx.conf.epp', {
      'server_name' => $server_name,
      'has_cert'    => $has_cert,
    }),
    require => Package['nginx'],
    notify  => Service['nginx'],
  }

  service { 'nginx':
    ensure  => running,
    enable  => true,
    require => Selboolean['httpd_can_network_connect'],
  }

  exec { 'certbot obtain certificate':
    command => join([
      '/usr/bin/certbot certonly --webroot -w /var/www/letsencrypt',
      "-d ${server_name} -m ${letsencrypt_email} --agree-tos -n",
    ], ' '),
    creates => "/etc/letsencrypt/live/${server_name}/fullchain.pem",
    require => [Service['nginx'], File['/var/www/letsencrypt']],
  }

  # The certbot package ships certbot-renew.timer; renewed certificates
  # must reload nginx to be served.
  service { 'certbot-renew.timer':
    ensure  => running,
    enable  => true,
    require => Package['certbot'],
  }

  file { '/etc/letsencrypt/renewal-hooks/deploy/reload-nginx':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => "#!/bin/sh\n# This file is managed by Puppet.\nsystemctl reload nginx\n",
    require => Package['certbot'],
  }
}
