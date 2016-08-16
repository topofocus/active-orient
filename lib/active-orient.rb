
module OrientDB
  UsingJava = RUBY_PLATFORM == 'java' ?  true : false
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
#require_relative "query.rb"
if RUBY_PLATFORM == 'java'
  require_relative 'java-api.rb'
  end
require_relative "orientdb_private.rb" # manage private functions
require_relative "database_utils.rb" #common methods without rest.specific content
require_relative "class_utils.rb" #common methods without rest.specific content
require_relative "other.rb"
require_relative "rest/rest.rb"
require_relative "model/model.rb"
require 'active_support/core_ext/string' # provides blank?, present?, presence etc

module  ActiveOrient
mattr_accessor :database
mattr_accessor :database_classes
mattr_accessor :default_server
end

