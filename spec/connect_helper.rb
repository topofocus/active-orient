require 'stringio'
require 'rspec/expectations'

def connect database: 'MyTest'
 config_file = File.expand_path('../../config/connect.yml', __FILE__)
 if config_file.present?
   connectyml  = YAML.load_file( config_file )[:orientdb]
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
	
		ActiveOrient::Init.connect  database: database,
											#					logger:  mock_logger,
																server:  connectyml[:server],
																port:    2480,
																user:   connectyml[:admin][:user], 
																password: connectyml[:admin][:pass] 
			# returns an instance to the database-client
end



## Logger helpers

def mock_logger
  @stdout = StringIO.new

  logger = Logger.new(@stdout).tap do |l|
    l.formatter = proc do |level, time, prog, msg|
      "#{time.strftime('%H:%M:%S')} #{msg}\n"
    end
    l.level = Logger::INFO
  end
end

def log_entries
  @stdout && @stdout.string.split(/\n/)
end


def should_log *patterns
  patterns.each do |pattern|
   expect( log_entries.any? { |entry| entry =~ pattern }).to be_truthy
  end
end

def should_not_log *patterns
  patterns.each do |pattern|
    expect( log_entries.any? { |entry| entry =~ pattern }).to be_falsey
  end
end


