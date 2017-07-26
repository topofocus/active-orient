
module  ActiveOrient
  class Railtie < Rails::Railtie
    puts "Railtie included!!"
    initializer 'active_orient.logger' do
      ActiveSupport.on_load(:active_orient) do
	ActiveOrient::Base.logger =  Rails.logger
	ActiveOrient::OrientDB.logger =  Rails.logger
	#self.logger ||= Rails.logger
      end
    end


    initializer 'active_orient.initialize_database_access' do
#      config.active_orient = ActiveSupport::OrderedOptions.new
      begin
	config_file = Rails.root.join('config', 'config.yml')
	configyml  = YAML.load_file(  config_file )[:active_orient]
	connect_file = Rails.root.join('config', 'connect.yml')
	connectyml  = YAML.load_file(  connect_file )[:orientdb][:admin]
	databaseyml  = YAML.load_file(  connect_file )[:orientdb][:database]
      rescue Errno::ENOENT => e
	Rails.logger.error{ "config/connect.yml/config.yml not present"  }
	puts "config/***yml not present"
	Rails.logger.error{ "Using defaults to connect database-server"  }
	puts "Using defaults to connect database-server"
      end
      ## Rails.root is a Pathname, as well as model_dir
      ActiveOrient::Model.model_dir = Rails.root.join  configyml.present? ? configyml[:model_dir] : "app/model" 

      # set the database
      ActiveOrient.database = databaseyml[Rails.env.to_sym] || 'temp'

       # don't allocate models if no file is provided
       ActiveOrient::Model.keep_models_without_file = false

       if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
        ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
	                               server: 'localhost', port: 2480  }
       end
       ActiveOrient::Init.define_namespace namespace: :object
       ::DB = ::ORD = ActiveOrient::OrientDB.new  preallocate: true

    end

    # We're not doing migrations (yet)
    config.send(:app_generators).orm :active_orient, migration: false
    console do
	Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
	puts '_'*45
	 puts "ORD points to the REST-Instance, Database: #{ActiveOrient.database}"
	 puts "DB is the API-Instance of the database, DB.db gets the DB-Api-base " if RUBY_PLATFORM == 'java'
	 
	 puts '-'* 45
	 ns= case ActiveOrient::Model.namespace 
	          when Object
	            "No Prefix, just ClassName#CamelCase"
	            else
	             ActiveOrient::Model.namespace.to_s + "{ClassName.camelcase}"
	            end
	 puts "Namespace for model-classes : #{ns}"
	 puts "Present Classes (Hierarchy) "
	 
	 puts ::ORD.class_hierarchy.to_yaml
	 puts ActiveOrient::show_classes
    end
  end
end
