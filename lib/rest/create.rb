module RestCreate

  ######### DATABASE ##########

=begin
  Creates a database with the given name and switches to this database as working-database. Types are either 'plocal' or 'memory'

  Returns the name of the working-database
=end

	def create_database type: 'plocal', database: 
		logger.progname = 'RestCreate#CreateDatabase'
		old_d = ActiveOrient.database
		ActiveOrient.database_classes = {} 
		ActiveOrient.database = database 
			begin
				response = ActiveOrient.db_pool.checkout do | conn |
					 conn["database/#{ActiveOrient.database}/#{type}"].post ""
				end
				if response.code == 200
					logger.info{"Database #{ActiveOrient.database} successfully created and stored as working database"}
				else
					logger.error{"Database #{ActiveOrient.database} was NOT created. Working Database is still #{ActiveOrient.database}"}
					ActiveOrient.database = old_d
				end
			rescue RestClient::InternalServerError => e
				logger.error{"Database #{ActiveOrient.database} was NOT created. Working Database is still #{ActiveOrient.database}"}
				ActiveOrient.database = old_d
			end
			ActiveOrient.database  # return_value
	end



=begin

This is the historic method CreateClasses. It's just performing the database-stuff and now private

it takes superclass and abstract (a hash) as block

usually, only one classname is provided, however the method takes a row of classnames as argument

#todo reintegrate the ability to create abstract classes
=end
private
def create_this_class  *db_classname  #nodoc#
	if block_given?
		additional_args =     yield
		superclass = additional_args[ :superclass ]
		abstract = additional_args[ :abstract ].presence || nil
	else 
		superclass = nil
		abstract =  nil
	end
	#
	 db_classname.map do | database_class |
		c = if superclass.present?
					"CREATE CLASS #{database_class} EXTENDS #{superclass}" 
				else
					"CREATE CLASS #{database_class} "
				end
		c << " ABSTRACT" if abstract.present?
		execute( tolerated_error_code: /already exists/ ){ c }	
	end
    # execute anything as batch, don't roll back in case of an error

#   execute transaction: false, tolerated_error_code: /already exists/ do
#      command
#    end
   
  rescue ArgumentError => e
    logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
  end


public

  ############## OBJECT #############



=begin
Creates a Record in the Database and returns this as ActiveOrient::Model-Instance

Creates a Record with the attributes provided in the attributes-hash e.g.
   create_record @classname, attributes: {con_id: 343, symbol: 'EWTZ'}

Puts the database-response into the cache by default


=end

  def create_record o_class, attributes: {}, cache: true    # use Model#create instead
    logger.progname = 'RestCreate#CreateRecord'
    attributes = yield if attributes.empty? && block_given?
    # @class must not quoted! Quote only attributes(strings)
    post_argument = {'@class' => classname(o_class)}.merge(attributes.to_orient)
		response = nil
    begin
			response = ActiveOrient.db_pool.checkout do | conn |
				conn["/document/#{ActiveOrient.database}"].post post_argument.to_json
			end
      data = JSON.parse(response.body)
      the_object = ActiveOrient::Model.orientdb_class(name: data['@class']).new data ## return_value
      if cache 
				ActiveOrient::Base.store_rid( the_object ) 
      else
				the_object
      end
    rescue RestClient::InternalServerError => e
      sentence=  JSON.parse( e.response)['errors'].last['content']
#      puts sentence.to_s
      if sentence =~ /found duplicated key/
				rid = sentence.split("#").last
				logger.info{ "found duplicated Key --> loaded #{rid} instead of creating "}
				## reading database content -- maybe update attributes?
				get_record rid
			else
				response = JSON.parse(e.response)['errors'].pop
				logger.error{response['content'].split(':')[1..-1].join(':')}
				logger.error{"No Object allocated"}
				nil # return_value
			end
    rescue Errno::EADDRNOTAVAIL => e
      sleep(2)
      retry
    end
  end
  alias create_document create_record

# UPDATE <class>|CLUSTER:<cluster>|<recordID>
#   [SET|INCREMENT|ADD|REMOVE|PUT <field-name> = <field-value>[,]*]|[CONTENT|MERGE <JSON>]
#     [UPSERT]
#       [RETURN <returning> [<returning-expression>]]
#         [WHERE <conditions>]
#           [LOCK default|record]
#             [LIMIT <max-records>] [TIMEOUT <timeout>]

=begin
update or insert one record is implemented as upsert.
The where-condition is merged into the set-attributes if its a hash.  
Otherwise it's taken unmodified.

The method returns the included or the updated dataset

## to do
# yield works for updated and for inserted datasets
# upsert ( ) do | what, record |
# if what == :insert 
#   do stuff with insert
#   if what ==  :update
#   do stuff with update
# end
# returns nil if no insert and no update was made, ie. the dataset is identical to the given attributes
=end
	def upsert o_class, set: , where:    #    use Model#Upsert instead
		logger.progname = 'RestCreate#Upsert'
		specify_return_value =  "return after @rid"
		#			set.merge! where if where.is_a?( Hash ) # copy where attributes to set 
		command = "Update #{classname(o_class)} set #{generate_sql_list( set ){','}} upsert #{specify_return_value}  #{compose_where where}" 
		result = execute( tolerated_error_code: /found duplicated key/){ command }	
	#	puts "result #{result.inspect}"
		result =result.pop if result.is_a? Array
	end
  ############### PROPERTIES #############

=begin
Creates properties  

and (if defined in the provided block)  associates an index
    create_properties(classname or class, properties as hash){index}

The default-case
    create_properties(:my_high_sophisticated_database_class,
  		con_id: {type: :integer},
  		details: {type: :link, linked_class: 'Contracts'}) do
  		  contract_idx: :notunique
  		end

A composite index
    create_properties(:my_high_sophisticated_database_class,
  		con_id: {type: :integer},
  		symbol: {type: :string}) do
  	    {name: 'indexname',
  			 on: [:con_id, :details]    # default: all specified properties
  			 type: :notunique            # default: :unique
  	    }
  		end
=end

	def create_properties o_class, all_properties, &b
		logger.progname = 'RestCreate#CreateProperties'
		all_properties_in_a_hash = Hash.new  #WithIndifferentAccess.new
		all_properties.each{|field, args| all_properties_in_a_hash.merge! translate_property_hash(field, args)}
		count, response = 0, nil
#		puts "all_properties_in_a_hash #{all_properties_in_a_hash.to_json}"
		if all_properties_in_a_hash.is_a?(Hash)
			begin
				response = ActiveOrient.db_pool.checkout do | conn |
					 conn["/property/#{ActiveOrient.database}/#{classname(o_class)}"].post all_properties_in_a_hash.to_json
				end
					#				puts response.inspect
					# response.body.to_i returns  response.code, only to_f.to_i returns the correct value
					count= response.body.to_f.to_i if response.code == 201
			rescue RestClient::InternalServerError => e
				logger.progname = 'RestCreate#CreateProperties'
				response = JSON.parse(e.response)['errors'].pop
				error_message = response['content'].split(':').last
				logger.error{"Properties in #{classname(o_class)} were NOT created"}
				logger.error{"The Error was: #{response['content'].split(':').last}"}
				nil
			end
		end
		### index
		if block_given?# && count == all_properties_in_a_hash.size
			index = yield
			if index.is_a?(Hash)
				if index.size == 1
					create_index o_class, name: index.keys.first, on: all_properties_in_a_hash.keys, type: index.values.first
				else
					index_hash =  {type: :unique, on: all_properties_in_a_hash.keys}.merge index
					create_index o_class,  name: index_hash[:name], on: index_hash[:on], type: index_hash[:type]
				end
			end
		end
		count  # return_value
	end

=begin
Create a single property.

Supported types: https://orientdb.com/docs/last/SQL-Create-Property.html
 
If an index is to be specified, it's defined in the optional block

  create_property(class, field){:unique | :notunique}	                    
  --> creates an automatic-Index on the given field
  
  create_property(class, field){{»name« => :unique | :notunique | :full_text}} 
  --> creates a manual index
=end

	def create_property o_class, field, index: nil, **args, &b
		logger.progname = 'RestCreate#CreateProperty'
		args= { type: :string} if args.blank?  # the default case
		c = create_properties o_class, {field => args}
		if index.nil? && block_given?
			index = yield
		end
		if index.present?
			if index.is_a?(String) || index.is_a?(Symbol)
				create_index o_class, name: field, type: index
			elsif index.is_a? Hash
				bez = index.keys.first
				create_index o_class, name: bez, type: index[bez], on: [field]
			end
		end
	end

  ################# INDEX ###################

# Used to create an index

  def create_index o_class, name:, on: :automatic, type: :unique
    logger.progname = 'RestCreate#CreateIndex'
      c = classname o_class
			if  execute( transaction: false, tolerated_error_code: /found duplicated key/) do
				if on == :automatic
					"CREATE INDEX #{c}.#{name} #{type.to_s.upcase}"
				elsif on.is_a? Array
					"CREATE INDEX #{name} ON #{c}(#{on.join(', ')}) #{type.to_s.upcase}"
				else
					"CREATE INDEX #{name} ON #{c}(#{on.to_s}) #{type.to_s.upcase}"
				end
			end

			logger.info{"Index on #{c} based on #{name} created."}
			else
				logger.error {"index #{name}.#{type} on  #{c}  NOT created"}
			end
	end

end
