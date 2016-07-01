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
rescue Errno::ENOENT => e
  ActiveOrient::Base.logger = Logger.new('/dev/stdout')
  ActiveOrient::OrientDB.logger.error{ "config/connectyml not present"  }
  ActiveOrient::OrientDB.logger.error{ "Using defaults to connect database-server"  }

end

e=  ARGV.present? ? ARGV.last.downcase : 'development'
env =  if e =~ /^p/
	 'production'
       elsif e =~ /^t/
	 'test'
       else
	 'development'
       end
puts "Using #{env}-environment"
databaseyml   = YAML.load_file( config_file )[:orientdb][:database]
log_file =   if config_file.present?
	       dev = YAML.load_file( config_file )[:orientdb][:logger]
	       if dev.blank? || dev== 'stdout'
		 '/dev/stdout'
	       else
		 project_root+'/log/'+env+'.log'
	       end
	     end


logger =  Logger.new log_file
logger.level = case env
	       when 'production' 
		 Logger::ERROR
	       when 'development'
		 Logger::WARN
	       else
		 Logger::INFO
	       end
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{progname}:..:#{msg}\n"
end
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: 'localhost', port: 2480  }
  ActiveOrient.database = databaseyml[env.to_sym]
  ORD = ActiveOrient::OrientDB.new  preallocate: true
  if RUBY_PLATFORM == 'java'
    DB =  ActiveOrient::API.new   preallocate: false
  else
    DB = ORD
  end

else
  ActiveOrient::Base.logger = Logger.new('/dev/stdout')
  ActiveOrient::OrientDB.logger.error{ "config/connectyml is  misconfigurated" }
  ActiveOrient::OrientDB.logger.error{ "Database Server is NOT available"} 
end



