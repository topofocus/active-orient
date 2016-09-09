## parameters
## @namespace : Class on which ActiveOrient::Model's should base
## @do_not_preallocate : avoid preallocation upon boot

require 'bundler/setup'
require 'yaml'
require 'active-orient'
if RUBY_VERSION == 'java'
  require 'orientdb'
end
project_root = File.expand_path('../..', __FILE__)
#require "#{project_root}/lib/active-orient.rb"
# mixin for define_namespace 

# make shure that E and V are required first => sort by length
models= Dir.glob(File.join( project_root, "model",'**', "*rb")).sort{|x,y| x.size <=> y.size }

begin
  connect_file = File.expand_path('../../config/connect.yml', __FILE__)
  config_file = File.expand_path('../../config/config.yml', __FILE__)
  connectyml  = YAML.load_file( connect_file )[:orientdb][:admin] if connect_file.present?
  configyml  = YAML.load_file( config_file )[:active_orient] if config_file.present?
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


# lib/init.rb
module TG
end
ActiveOrient::Init.define_namespace { TG }

ActiveOrient::Model.model_dir =  "#{project_root}/#{ configyml.present? ? configyml[:model_dir] : "model" }"
puts "BOOT--> Project-Root:  #{project_root}"
puts "BOOT--> mode-dir:  #{ActiveOrient::Model.model_dir}"

databaseyml   = YAML.load_file( connect_file )[:orientdb][:database]
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
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: 'localhost', port: 2480  }
  ActiveOrient.database = @configDatabase.presence || databaseyml[env.to_sym]

  ## Include customized NamingConvention for Edges
  ActiveOrient::Model.orientdb_class name:"E"
  ActiveOrient::Model.orientdb_class name:"V"
  class E #< ActiveOrient::Model
      def self.naming_convention name=nil
          name.present? ? name.upcase : ref_name.upcase
      end
  end


  ORD = ActiveOrient::OrientDB.new  preallocate: @do_not_preallocate.present? ? false : true 
  if RUBY_PLATFORM == 'java'
    DB =  ActiveOrient::API.new   preallocate: false
  else
    DB = ORD
  end

#  ORD.create_classes 'E', 'V'
#  E.ref_name = 'E'
#  V.ref_name = 'V'

# require model files after initializing the database
#    require "#{project_root}/model/edge.rb"
#    require "#{project_root}/model/vertex.rb"

# require db-init and application
     require "#{project_root}/config/init_db.rb"
     require "#{project_root}/lib/createTime.rb"

# thus the classes are predefined and modelfiles just extend the classes
#included_models = models.collect { |file| [file, require( file )] }
#puts "Included Models: "
#puts included_models.collect{|x,y| [ "\t",x.split("/").last , " \t-> " , y].join }.join("\n")
else
  ActiveOrient::Base.logger = Logger.new('/dev/stdout')
  ActiveOrient::OrientDB.logger.error{ "config/connectyml is  misconfigurated" }
  ActiveOrient::OrientDB.logger.error{ "Database Server is NOT available"} 
end



