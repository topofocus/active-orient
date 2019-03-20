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
ActiveOrient::Model.keep_models_without_file = true
# lib/init.rb
ActiveOrient::Init.define_namespace yml: configyml, namespace: @namespace


log_file =   if config_file.present?
	       dev = YAML.load_file( connect_file )[:orientdb][:logger]
	       if dev.blank? || dev== 'stdout'
		 '/dev/stdout'
	       else
		 project_root+'/log/'+env+'.log'
	       end
	     end


logger = Logger.new(log_file)
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
ActiveOrient::OrientDB.logger = logger # 

#ActiveOrient::OrientDB.configure_logger logger # 
#ActiveOrient::Base.configure_logger logger # 


if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: '172.28.50.25', port: 2480  }
  ActiveOrient.database = @configDatabase.presence || databaseyml[env.to_sym]

# because V and E are present in any case,  edge+vertex initialisation is required in model/model.rb
# however, the Objects have to be initialized separately. This is performed prior to the connection
# to the database
 # V.ref_name = 'V'
 # E.ref_name = 'E'

  ORD = ActiveOrient::OrientDB.new  preallocate: @do_not_preallocate.present? ? false : true
  if RUBY_PLATFORM == 'java'
    DB =  ActiveOrient::API.new   preallocate: false
  else
    DB = ORD
  end

  # require model files after initializing the database  # the historic solution works, too
#  gem_root = `bundle show active-orient`[0..-2]
#  require "#{gem_root}/lib/model/edge.rb"
#  require "#{gem_root}/lib/model/vertex.rb"
## attention: if the Egde- or Vertex-Base-Class is deleted (V.delte_class) the model-methods are gone.
## After recreating the BaseClass by ORD.create_class('V'), the model-classes have to be loaded manually (require does not work))
else
    puts "config/connect.yml is  misconfigurated" 
    puts "Database Server is NOT available"
    Kernel.exit
end



