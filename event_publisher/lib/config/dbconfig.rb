require 'configuration'

Configuration.for('event_publisher_long_term_storage') {
  db_user_name             'SPA_event_publish_guy'
  db_password              'SPA_123'
  db_server_name           'ec2-107-20-228-67.compute-1.amazonaws.com'
  db_name_event_source     'spa_test'
  db_port                  1433
}
