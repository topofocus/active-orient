# boot_spec
# 
# env --> test
# logfile --> log/test.log
# modelfiles --> spec/modelfiles
# namespace --> Object
# 
# Database is NOT connected, no ruby-class is allocated
require 'bundler/setup'
require 'yaml'
if RUBY_VERSION == 'java'
  require 'orientdb'
end
project_root = File.expand_path('../..', __FILE__)
require "#{project_root}/lib/active-orient.rb"
begin
  connect_file = File.expand_path('../../config/connect.yml', __FILE__)
  config_file = File.expand_path('../../config/config.yml', __FILE__)
  connectyml  = YAML.load_file( connect_file )[:orientdb][:admin] if connect_file.present?
  configyml  = YAML.load_file( config_file )[:active_orient] if config_file.present?
  databaseyml   = YAML.load_file( connect_file )[:orientdb][:database] if connect_file.present?
rescue Errno::ENOENT 
   puts "config/connectyml not present"  
   puts "Using defaults to connect database-server"  
  end

env =  'test'

ActiveOrient::Model.model_dir =  "#{project_root}/spec/modelfiles"
ActiveOrient::Model.keep_models_without_file = true
# lib/init.rb
ActiveOrient::Init.define_namespace namespace: :object



log_file =  project_root+'/log/test.log'


logger = ActiveSupport::TaggedLogging.new( Logger.new(STDOUT)) # log_file))
logger.level = case env
	       when 'production' 
		 Logger::ERROR
	       when 'development'
		 Logger::WARN
	       else
		 Logger::INFO
	       end
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{msg}\n"
end
ActiveOrient::Base.logger =  logger
ActiveOrient::OrientDB.logger =  logger

if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: 'localhost', port: 2480  }
  ActiveOrient.database = databaseyml[:test]

#  ORD = ActiveOrient::OrientDB.new  preallocate: @do_not_preallocate.present? ? false : true
#  if RUBY_PLATFORM == 'java'
#    DB =  ActiveOrient::API.new   preallocate: false
#  else
#    DB = ORD
#  end
#
else
    puts "config/connect.yml is  misconfigurated" 
    puts "Database Server is NOT available"
    Kernel.exit
end
#


