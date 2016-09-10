require 'active-orient'
require_relative 'createTime.rb'
require_relative '../config/init_db'



module TG

  def self.set_defaults  login =  nil
    c = { :server => 'localhost',
	  :port   => 2480,
	  :protocol => 'http',
	  :user    => 'root',
	  :password => 'root',
	  :database => 'temp'
    }.merge login.presence || {}

    ActiveOrient.default_server= { user: c[:user], password: c[:password] ,
				   server: c[:server], port: c[:port]  }
    ActiveOrient.database = c[:database]
    logger =  Logger.new '/dev/stdout'
    ActiveOrient::Base.logger =  logger 
    ActiveOrient::OrientDB.logger = logger 
  end
  def self.connect login =  nil
    project_root = File.expand_path('../..', __FILE__)

    set_defaults(login) if ActiveOrient::Base.logger.nil? 
    ActiveOrient::Init.define_namespace { TG } 
    ActiveOrient::Model.model_dir =  "#{project_root}/model"
    ActiveOrient::OrientDB.new  preallocate: true  # connect via http-rest
  end
end





