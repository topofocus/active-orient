require 'bundler/setup'
require 'yaml'
project_root = File.expand_path('../..', __FILE__)

# require all the models and libraries
libs= Dir.glob(File.join( project_root, "lib",'**', "*rb")) 
result = libs.reverse.collect { |file| [file, require( file )] }





