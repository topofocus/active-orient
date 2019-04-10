module ActiveOrient
  module Init

=begin
Connects to an OrientDB-Server

A sample configuration:

  	 config_file = File.expand_path('../../config/connect.yml', __FILE__)
  	 if config_file.present?
  		 connectyml  = YAML.load_file( config_file )[:orientdb]
  	 else
  		puts "config/connect.yml not found or misconfigurated"
  		Kernel.exit
  	 end

  	 ActiveOrient::Init.connect  database: database,
						server:  connectyml[:server],
						port:    2480,
						user:   connectyml[:admin][:user], 
						password: connectyml[:admin][:pass] 


We are setting up Base-classes E and V which is required for a proper initialisation
and allocate the logger.

No other class is loaded.

This has to be done in subsequent calls of 
	 ao = ActiveOrient::OrientDB.new 
	

returns the active OrientDB-Instance


=end
		def self.connect **defaults
				define_namespace  namespace: :object 
				ActiveOrient::OrientDB.configure_logger defaults[:logger]
        ao = ActiveOrient::OrientDB.new  defaults.merge preallocate: false
				ao.create_class 'E'
				ao.create_class 'V'
				ao  # return client instance
		end
=begin
Parameters: 
 yml: hash from config.yml , 
 namespace: Class to use as Namespace

A custom Constant can be provided via Block

i.e.
  configyml =  YAML.load_file (...)  # with an entry "namespace:" 
  ActiveOrient.Init.define_namespace yml: configyml 
  #or
  ActiveOrient.Init.define_namespace namespace: :self | :object | :active_orient
	#or
	module IBi; end # first declare the Module-Const
  # then assign to the namespace
  ActiveOrient.Init.define_namespace { IB } 
		
=end
    def self.define_namespace(  yml: {}, namespace: nil )
      n =  namespace.presence || yml[:namespace].presence || :object
			ActiveOrient::Model.namespace = if block_given?
																				yield
																			else
																				case n
																				when :self
																					ActiveOrient::Model
																				when :object
																					Object
																				when :active_orient
																					ActiveOrient
																				end
																			end
		end # define namespace
  end # module Init
end  # module ActiveOrient
