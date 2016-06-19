require_relative "other.rb"
require_relative "support.rb"
require_relative "base.rb"
require_relative "base_properties.rb"
require_relative "orient.rb"
require_relative "model.rb"
#require_relative "query.rb"
if RUBY_PLATFORM == 'java'
  require_relative 'jdbc.rb'
  end
require_relative "rest.rb"

logger =  Logger.new '/dev/stdout'
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{progname}:..:#{msg}\n"
end
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
