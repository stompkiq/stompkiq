require 'configuration'

Configuration.for('logreceiver') {
  logdir './log'
  logfilename 'logreceiver.log'
  bus_username 'admin'
  bus_password 'password'
  bus_location '127.0.0.1'
  bus_port 61613
  bus_queue_for_log_events "/queue/event_source:log"
}
