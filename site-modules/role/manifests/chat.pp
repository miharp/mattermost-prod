# The production Mattermost server.
class role::chat {
  include profile::base
  include profile::mattermost
  include profile::nginx
  include profile::backup
}
