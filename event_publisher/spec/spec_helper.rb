require 'pathname'
ROOT_PATH = Pathname.new File.expand_path(File.join(File.dirname(__FILE__), '..'))
$LOAD_PATH.unshift ROOT_PATH + 'lib'

require 'event_scanner'
require 'event_publisher'
require 'rspec'

