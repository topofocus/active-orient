#### sample boot file ####



require 'bundler/setup'
require 'yaml'
if RUBY_VERSION == 'java'
	require 'orientdb'
end
require "active-orient"
project_root = File.expand_path('../..', __FILE__)
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
				 :production
			 elsif e =~ /^t/
				 :test
			 else
				 :development
			 end
puts "Using #{env}-environment"

log_file =   if File.exist?(config_file)
							 dev = YAML.load_file( connect_file )[:orientdb][:logger]
							 if dev.blank? || dev== 'stdout'
								 '/dev/stdout'
							 else
								 project_root+'/log/'+env+'.log'
							 end
						 end


logger = Logger.new(log_file)
logger.level = case env
							 when :production 
								 Logger::ERROR
							 when :development
								 Logger::WARN
							 else
								 Logger::INFO
							 end
logger.formatter = proc do |severity, datetime, progname, msg|
	"#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{msg}\n"
end

 ORD = ActiveOrient::Init.connect database: databaseyml[env],
														user: connectyml[:user].to_s,
														password: connectyml[:pass].to_s,
														server: '172.28.50.25',
														logger: logger



 ActiveOrient::Model.keep_models_without_file = true
 ActiveOrient::Init.define_namespace yml: configyml, namespace: @namespace
 ActiveOrient::OrientDB.new  preallocate:  true, 
			model_dir: "#{project_root}/#{ configyml.present? ? configyml[:model_dir] : "model" }"

  if RUBY_PLATFORM == 'java'
    DB =  ActiveOrient::API.new   preallocate: false
  else
    DB = ORD
  end




