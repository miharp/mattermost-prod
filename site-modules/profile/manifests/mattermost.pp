# Mattermost itself, plus its local PostgreSQL — both entirely via the
# miharp/puppet-mattermost module, configured through hiera (data/common.yaml
# and the uncommitted data/secrets.yaml).
class profile::mattermost {
  include mattermost
}
