require "other.rb"
require "support.rb"
require "base.rb"
require "base_properties.rb"
require "orient.rb"
require "model.rb"
require "query.rb"
require "rest.rb"

logger =  Logger.new '/dev/stdout'
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
