project_root = File.expand_path('../../..', __FILE__)
config_root = File.expand_path('../..', __FILE__)
puts "Project_root: #{project_root}"
puts "Config_root: #{config_root}"
begin
  connect_file = File.expand_path('../../connect.yml', __FILE__)
  config_file = File.expand_path('../../config.yml', __FILE__)
  connectyml  = YAML.load_file( connect_file )[:orientdb][:admin] if connect_file.present?
  configyml  = YAML.load_file(  config_file )[:active_orient] if config_file.present?
  databaseyml   = YAML.load_file( connect_file )[:orientdb][:database] if connect_file.present?
rescue Errno::ENOENT => e
  Rails.logger.error{ "config/connect.yml not present"  }
  puts "config/connectyml not present"  
  Rails.logger.error{ "Using defaults to connect database-server"  }
  puts "Using defaults to connect database-server"  

end

puts "Environment: #{Rails.env}"
puts ActiveOrient::Model.name


ActiveOrient::Model.model_dir =  "#{project_root}/#{ configyml.present? ? configyml[:model_dir] : "model" }"
ActiveOrient::Model.keep_models_without_file = true
# lib/init.rb
ActiveOrient::Init.define_namespace yml: configyml, namespace: @namespace



Rails.logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{progname}:..:#{msg}\n"
end
ActiveOrient::Base.logger =  Rails.logger
ActiveOrient::OrientDB.logger =  Rails.logger

if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: 'localhost', port: 2480  }
  ActiveOrient.database = @configDatabase.presence || databaseyml[Rails.env.to_sym]

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
else
  logger = Logger.new('/dev/stdout')
  logger.error{ "config/connectyml is  misconfigurated" }
  logger.error{ "Database Server is NOT available"} 
end



