forge 'https://forge.puppet.com'

mod 'puppetlabs/stdlib',     '10.0.2'
mod 'puppetlabs/apt',        '11.3.2'
mod 'puppet/archive',        '8.1.0'
mod 'puppetlabs/postgresql', '10.6.3'
mod 'puppetlabs/concat',     '10.0.1'
mod 'puppet/systemd',        '10.0.0'

# Pin to a branch for now; switch to a tag once puppet-mattermost cuts a
# release. NOTE: r10k on the server can only clone this if the repo is
# public (or a deploy key is configured) — see README.
mod 'mattermost',
  git:    'https://github.com/miharp/puppet-mattermost.git',
  branch: 'main'
