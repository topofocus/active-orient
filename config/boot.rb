require 'bundler/setup'
require 'yaml'
if RUBY_VERSION == 'java'
  require 'orientdb'
end
project_root = File.expand_path('../..', __FILE__)
require "#{project_root}/lib/active-orient.rb"
# mixin for define_namespace 
include ActiveOrient::Init
begin
  connect_file = File.expand_path('../../config/connect.yml', __FILE__)
  config_file = File.expand_path('../../config/config.yml', __FILE__)
  connectyml  = YAML.load_file( connect_file )[:orientdb][:admin] if connect_file.present?
  configyml  = YAML.load_file( config_file )[:active_orient] if config_file.present?
  databaseyml   = YAML.load_file( connect_file )[:orientdb][:database] if connect_file.present?
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

ActiveOrient::Model.model_dir =  "#{project_root}/#{ configyml.present? ? configyml[:model_dir] : "model" }"

# lib/init.rb
define_namespace yml: configyml, namespace: @namespace


log_file =   if config_file.present?
	       dev = YAML.load_file( connect_file )[:orientdb][:logger]
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
ActiveOrient::Base.logger =  logger
ActiveOrient::OrientDB.logger =  logger

if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: 'localhost', port: 2480  }
  ActiveOrient.database = @configDatabase.presence || databaseyml[env.to_sym]

  ORD = ActiveOrient::OrientDB.new  preallocate: @do_not_preallocate.present? ? false : true
  if RUBY_PLATFORM == 'java'
    DB =  ActiveOrient::API.new   preallocate: false
  else
    DB = ORD
  end
#  ActiveOrient::Init.vertex_and_edge_class

      ORD.create_classes 'E', 'V'
      E.ref_name = 'E'
      V.ref_name = 'V'
  # require model files after initializing the database
  require "#{project_root}/lib/model/edge.rb"
  require "#{project_root}/lib/model/vertex.rb"
## attention: if the Egde- or Vertex-Base-Class is deleted (V.delte_class) the model-methods are gone.
## After recreating the BaseClass by ORD.create_class('V'), the model-classes have to be loaded manually (require does not work))
else
  ActiveOrient::Base.logger = Logger.new('/dev/stdout')
  ActiveOrient::OrientDB.logger.error{ "config/connectyml is  misconfigurated" }
  ActiveOrient::OrientDB.logger.error{ "Database Server is NOT available"} 
end



