require 'bundler/setup'
require 'yaml'
project_root = File.expand_path('../..', __FILE__)
require "#{project_root}/lib/base.rb"
require "#{project_root}/lib/base_properties.rb"

require "#{project_root}/lib/model.rb"
require "#{project_root}/lib/rest.rb"
#require "#{project_root}/lib/graph.rb"

# require all the models and libraries
libs= Dir.glob(File.join( project_root, "lib",'**', "*rb")) 
result = libs.reverse.collect { |file| [file, require( file )] }

logger =  Logger.new '/dev/stdout'
#REST::Graph.logger =  logger
REST::Model.logger =  logger
REST::OrientDB.logger =  logger




