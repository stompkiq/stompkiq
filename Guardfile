# A sample Guardfile
# More info at https://github.com/guard/guard#readme
#require 'guard-minitest'

guard 'minitest', :bundler => true, :cli => "--verbose", :notify => true do
#  with MiniTest::Unit
  watch(%r|^test/(.*)\/?test_(.*)\.rb|)
  watch(%r|^lib/(.*?)([^/]+)\.rb|)  { |m| "test/test_#{m[2]}.rb" } #{ |m| f = "test/test_#{m[2]}.rb"; puts '-' * 80; puts f; puts '-' * 80; f }
  watch(%r|^test/helper\.rb|)    { "test" }

#  with MiniTest::Spec
  watch(%r|^spec/(.*)_spec\.rb|)
  watch(%r|^lib/(.*)([^/]+)\.rb|)     { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r|^spec/spec_helper\.rb|)    { "spec" }

end
