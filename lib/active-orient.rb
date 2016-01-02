require "support.rb"
require "base.rb"
require "base_properties.rb"

require "model.rb"
require "orient.rb"
require "rest.rb"

logger =  Logger.new '/dev/stdout'
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
