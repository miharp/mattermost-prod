# Mattermost itself, plus its local PostgreSQL — both entirely via the
# miharp/puppet-mattermost module, configured through hiera (data/common.yaml
# and the uncommitted data/secrets.yaml).
class profile::mattermost {
  # manage_database uses puppetlabs/postgresql defaults, and EL9's default
  # stream is PostgreSQL 13 — below Mattermost's required 14. Take 16 from
  # PGDG instead (same choice the module's acceptance suite makes).
  class { 'postgresql::globals':
    manage_package_repo => true,
    manage_dnf_module   => true,
    version             => '16',
  }

  include mattermost
}
