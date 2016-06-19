require 'bundler/setup'
require 'yaml'
if RUBY_VERSION == 'java'
  require 'orientdb'
end
project_root = File.expand_path('../..', __FILE__)
require "#{project_root}/lib/active-orient.rb"

 begin
   config_file = File.expand_path('../../config/connect.yml', __FILE__)

   connectyml  = YAML.load_file( config_file )[:orientdb][:admin] if config_file.present?
   if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
    ActiveOrient::OrientDB.default_server= { user: connectyml[:user], password: connectyml[:pass] }
   else
     ActiveOrient::Base.logger = Logger.new('/dev/stdout')
     ActiveOrient::OrientDB.logger.error{ "config/connectyml is  misconfigurated" }
     ActiveOrient::OrientDB.logger.error{ "Database Server is NOT available"} 
 end
 rescue Errno::ENOENT => e
   ActiveOrient::Base.logger = Logger.new('/dev/stdout')
   ActiveOrient::OrientDB.logger.error{ "config/connectyml not present"  }
   ActiveOrient::OrientDB.logger.error{ "Using defaults to connect to database-server"  }

 end

