require 'bundler/setup'
#require 'ib-ruby'
#require 'mail'
# add the lib/spec directories just like autotest does
#$:.unshift File.expand_path('./models')
#$:.unshift File.expand_path('./lib')
#$:.unshift File.expand_path('./spec')
#
project_root = File.expand_path('../..', __FILE__)

# require all the models and libraries
# first load 
#$LOAD_PATH.unshift project_root + '/ib-ruby/lib'
libs= Dir.glob(File.join( project_root, "lib",'**', "*rb")) 
result = libs.reverse.collect { |file| [file, require( file )] }





