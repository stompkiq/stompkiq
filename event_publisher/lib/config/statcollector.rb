require 'configuration'

Configuration.for('stat_collector') {
  logdir './log'
  logfilename 'statcollector.log'
  bus_username 'admin'
  bus_password 'password'
  bus_location '127.0.0.1'
  bus_port 61613
  topic_to_listen_to "/topic/{event_source:StompkiqProcessor}*"
}
