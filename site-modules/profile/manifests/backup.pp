# Nightly database dump with local rotation. With uploads in object storage
# (FileSettings/amazons3), the dump plus this repo is the entire restore
# story; until then /opt/mattermost/data needs to be included in whatever
# ships these dumps off the box.
#
# Off-site shipping (e.g. rclone to a Hetzner Storage Box) is deliberately
# left as the next step — dumps landing only on the same disk protect
# against software mistakes, not hardware loss.
class profile::backup {
  file { '/var/backups':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/backups/mattermost':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  file { '/usr/local/sbin/mattermost-backup':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => @(SCRIPT),
      #!/bin/bash
      # This file is managed by Puppet.
      set -euo pipefail
      dest=/var/backups/mattermost
      stamp=$(date +%Y%m%d-%H%M%S)
      sudo -u postgres pg_dump mattermost | gzip > "${dest}/mattermost-${stamp}.sql.gz"
      cp -p /etc/sysconfig/mattermost "${dest}/env-${stamp}" 2>/dev/null || true
      # Keep 14 days of dumps.
      find "${dest}" -type f -mtime +14 -delete
      | SCRIPT
  }

  file { '/etc/systemd/system/mattermost-backup.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(UNIT),
      # This file is managed by Puppet.
      [Unit]
      Description=Dump the Mattermost database

      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/mattermost-backup
      | UNIT
  }

  file { '/etc/systemd/system/mattermost-backup.timer':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(UNIT),
      # This file is managed by Puppet.
      [Unit]
      Description=Nightly Mattermost database dump

      [Timer]
      OnCalendar=*-*-* 03:30:00
      RandomizedDelaySec=600
      Persistent=true

      [Install]
      WantedBy=timers.target
      | UNIT
  }

  service { 'mattermost-backup.timer':
    ensure    => running,
    enable    => true,
    subscribe => File['/etc/systemd/system/mattermost-backup.timer'],
    require   => File['/usr/local/sbin/mattermost-backup'],
  }
}
