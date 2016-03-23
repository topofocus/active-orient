require_relative "other.rb"
require_relative "support.rb"
require_relative "base.rb"
require_relative "base_properties.rb"
require_relative "orient.rb"
require_relative "model.rb"
require_relative "query.rb"
require_relative "rest.rb"

logger =  Logger.new '/dev/stdout'
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
