## site.pp ##

File { backup => false }

# Single-node deployment: everything is the chat server.
node default {
  include role::chat
}
