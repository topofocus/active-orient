require "other"
require "support"
require "base"
require "base_properties"
require "orient"
require "model"
require "query"
require "rest"

logger =  Logger.new '/dev/stdout'
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
