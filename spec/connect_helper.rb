def connect database: 'MyTest'
 config_file = File.expand_path('../../config/connect.yml', __FILE__)
 if config_file.present?
   connectyml  = YAML.load_file( config_file )[:orientdb][:admin]
   puts "ConnectYaml" 
   puts connectyml.inspect
 else
   puts "config/connect.yml not found or misconfigurated"
   puts "expected: "
   puts <<EOS
:orientdb:
 :server: localhost
 :port: 2480
 :database: some_database
 :admin:
   :user: hctw
   :pass: hc
EOS
  Kernel.exit
 end
    ActiveOrient::OrientDB.logger =  ActiveOrient::Model.logger = Logger.new('/dev/stdout')
    ActiveOrient::OrientDB.default_server= { user: connectyml[:user], password: connectyml[:pass] }
    ActiveOrient::Base.logger = Logger.new('/dev/stdout')

    ActiveOrient::OrientDB.new database: database # returns an Instance to the database
  

end
