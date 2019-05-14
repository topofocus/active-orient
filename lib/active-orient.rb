
module OrientDB
  UsingJava = RUBY_PLATFORM == 'java' ?  true : false
  unless UsingJava
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
end  # module OrientDB
require 'active_model'
#require 'active_model/serializers'
require_relative "support/orientquery.rb"
require_relative "support/conversions.rb"
#require_relative "support/logging.rb"
require_relative "base.rb"
require_relative "base_properties.rb"
require_relative "support/orient.rb"
#require_relative "query.rb"
if OrientDB::UsingJava
  require_relative 'java-api.rb'
  end
require_relative "orientdb_private.rb" # manage private functions
require_relative "database_utils.rb" #common methods without rest.specific content
require_relative "class_utils.rb" #common methods without rest.specific content
require_relative "other.rb"
require_relative "rest/rest.rb"
require_relative "model/model.rb"
require 'active_support/core_ext/string' # provides blank?, present?, presence etc
require_relative 'init.rb'
# create Base Classes

require_relative "model/vertex.rb"
require_relative "model/edge.rb"

require_relative "railtie" if defined?(Rails)

module  ActiveOrient
mattr_accessor :database
mattr_accessor :db_pool
mattr_accessor :database_classes
mattr_accessor :default_server

## displays all allocated classes
##
## usage: 
##  puts ActiveOrient::show_classes
#
#
def self.show_classes

 '-'* 45+"\n"+
 "Database Class  ->  ActiveOrient ClassName\n"+
 '-'* 45+"\n"+
  ActiveOrient.database_classes.map{|x,y| "#{"%15s"% x} ->  #{y.to_s}" }.join("\n") + "\n"+
 '-'* 45 + "\n"
end

end

