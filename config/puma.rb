# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch('PORT') { 4000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch('SINATRA_ENV') { 'development' }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch('PIDFILE') { 'tmp/pids/server.pid' }
