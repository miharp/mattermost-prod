# Host groundwork: firewall, EPEL (certbot lives there), and the masterless
# puppet-apply timer that keeps this repo applied.
class profile::base {
  package { ['git', 'epel-release']:
    ensure => installed,
  }

  # Only 80/443 are exposed; Mattermost listens on loopback and PostgreSQL
  # is local-only. Two idempotent execs beat a firewall module dependency
  # for a single host.
  ['80', '443'].each |$port| {
    exec { "firewalld open ${port}/tcp":
      command => "firewall-cmd --add-port=${port}/tcp --permanent && firewall-cmd --reload",
      unless  => "firewall-cmd --query-port=${port}/tcp",
      path    => ['/usr/bin', '/usr/sbin'],
    }
  }

  # Re-apply the committed repo every 30 minutes: pull, resolve modules,
  # apply. scripts/run-puppet is what bootstrap ran by hand.
  file { '/etc/systemd/system/puppet-apply.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(UNIT),
      # This file is managed by Puppet.
      [Unit]
      Description=Apply the mattermost-prod control repo
      After=network-online.target

      [Service]
      Type=oneshot
      ExecStart=/opt/mattermost-prod/scripts/run-puppet
      | UNIT
  }

  file { '/etc/systemd/system/puppet-apply.timer':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(UNIT),
      # This file is managed by Puppet.
      [Unit]
      Description=Periodic puppet apply of mattermost-prod

      [Timer]
      OnCalendar=*:0/30
      RandomizedDelaySec=300
      Persistent=true

      [Install]
      WantedBy=timers.target
      | UNIT
  }

  service { 'puppet-apply.timer':
    ensure    => running,
    enable    => true,
    subscribe => File['/etc/systemd/system/puppet-apply.timer'],
  }
}
