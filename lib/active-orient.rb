
module OrientDB
  unless RUBY_PLATFORM == 'java'
   DocumentDatabase       = nil
   DocumentDatabasePool   = nil
   DocumentDatabasePooled = nil
   GraphDatabase          = nil
    OTraverse             = nil
    Document              = nil
    IndexType             = nil
    OClassImpl            = nil
    PropertyImpl          = nil
    Schema                = nil
    SchemaProxy           = nil
    SchemaType            = nil
    SQLCommand            = nil
    SQLSynchQuery         = nil
    User                  = nil
    RemoteStorage         = nil
    ServerAdmin           = nil
    # defined in other.rb
    #JavaDate		  
    #RecordList            = nil
   # RidBag		  = nil
   # RecordSet             = nil
  end
end
require_relative "support.rb"
require_relative "base.rb"
require_relative "base_properties.rb"
require_relative "orient.rb"
require_relative "model.rb"
#require_relative "query.rb"
if RUBY_PLATFORM == 'java'
  require_relative 'java-api.rb'
  end
require_relative "rest.rb"
require_relative "other.rb"

logger =  Logger.new '/dev/stdout'
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{progname}:..:#{msg}\n"
end
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger

module  ActiveOrient
mattr_accessor :database
mattr_accessor :database_classes
mattr_accessor :default_server
end

