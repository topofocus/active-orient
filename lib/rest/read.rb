module RestRead

  ############# DATABASE #############

# Returns an Array with available Database-Names as Elements
#
#    ORD.get_databases
#     => ["temp", "GratefulDeadConcerts", (...)] 
  def get_databases

		ActiveOrient.db_pool.checkout do | conn |
			JSON.parse(conn["/listDatabases"].get.body)['databases']
		end
  end

=begin
Returns an Array with (unmodified) Class-attribute-hash-Elements

»get_classes 'name', 'superClass'« returns
      [ {"name"=>"E", "superClass"=>""},
      {"name"=>"OFunction", "superClass"=>""},
      {"name"=>"ORole", "superClass"=>"OIdentity"}
      (...)    ]
=end
  def get_classes *attributes
		begin
			response = ActiveOrient.db_pool.checkout do | conn |
				conn["/database/#{ActiveOrient.database}"].get
			end
			if response.code == 200
				classes = JSON.parse(response.body)['classes']
				unless attributes.empty?
					classes.map{|y| y.select{|v,_| attributes.include?(v)}}
				else
					classes
				end
			else
				[]
			end
    rescue Exception => e
      logger.progname = 'RestRead#GetClasses'
      logger.error{e.message}
    end
  end


  ############### CLASS ################

# Returns a JSON of the property of a class
#
#   ORD.create_vertex_class a:
#   ORD.get_class_properties A
#    => {"name"=>"a", "superClass"=>"V", "superClasses"=>["V"], "alias"=>nil, "abstract"=>false, "strictmode"=>false, "clusters"=>[65, 66, 67, 68], "defaultCluster"=>65, "clusterSelection"=>"round-robin", "records"=>3} 
#
  def get_class_properties o_class
			ActiveOrient.db_pool.checkout do | conn |
				JSON.parse(conn["/class/#{ActiveOrient.database}/#{classname(o_class)}"].get)
			end
			rescue => e
				logger.error  e.message
				nil
			end


  def print_class_properties o_class
    puts "Detected Properties for class #{classname(o_class)}"
    rp = get_class_properties o_class
    n = rp['name']
    if rp['properties'].nil?
      puts "No property available"
    else
      puts rp['properties'].map{|x| "\t"+[n+'.'+x['name'], x['type'],x['linkedClass']].compact.join("\t-> ")}.join("\n")
    end
  rescue NoMethodError
    puts "Class #{o_class} not present in database"
  end

  ############## OBJECT #################

=begin
Retrieves a Record from the Database 

The argument can either be a rid "#{x}:{y}" or a link "{x}:{y}".

(to be specific: it must provide the methods rid? and to_orient, the latter must return the rid: "#[a}:{b}".)

If no Record is found, nil is returned

The rid-cache is not used or updated
=end

	def get_record rid
		begin
			logger.progname = 'RestRead#GetRecord'
			if rid.rid?

				response =  ActiveOrient.db_pool.checkout do | conn |
					 conn["/document/#{ActiveOrient.database}/#{rid.to_orient[1..-1]}"].get
				end
				raw_data = JSON.parse(response.body) 
				#	ActiveOrient::Model.use_or_allocate( raw_data['@rid'] ) do 
				the_object=   ActiveOrient::Model.orientdb_class(name: raw_data['@class']).new raw_data
				ActiveOrient::Base.store_rid( the_object )   # update cache
			else
				logger.error { "Wrong parameter #{rid.inspect}. " }
				nil
			end
		rescue RestClient::InternalServerError => e
			if e.http_body.split(':').last =~ /was not found|does not exist in database/
				nil
			else
				logger.error { "Something went wrong" }
				logger.error { e.http_body.inspect }
				raise
			end
		rescue RestClient::ResourceNotFound => e
			logger.error { "RID: #{rid} ---> No Record present " }
			ActiveOrient::Model.remove_rid rid      #  remove rid from cache
			nil
		rescue Exception => e
			logger.error { "Something went wrong" }
			logger.error { "RID: #{rid} - #{e.message}" }
			raise
		end
	end
	alias get_document get_record

=begin
Retrieves Records from a query

If raw is specified, the JSON-Array is returned, e.g.
    {"@type"=>"d", "@rid"=>"#15:1", "@version"=>1,    "@class"=>"DocumebntKlasse10", "con_id"=>343, "symbol"=>"EWTZ"}

Otherwise  ActiveModel-Instances are created and returned. 
In this case cached data are used in favour and its not checked if the database contents have changed.
=end

  def get_records raw: false, query: nil, **args
    query = OrientSupport::OrientQuery.new(args) if query.nil?
    begin
      logger.progname = 'RestRead#GetRecords'
			response =  ActiveOrient.db_pool.checkout do | conn |
				url = "/query/#{ActiveOrient.database}/sql/" + query.compose(destination: :rest) + "/#{query.get_limit}"
				conn[URI.encode(url)].get
			end
			JSON.parse(response.body)['result'].map do |record|
	    if raw
	      record
	      # query returns an anonymus class: Use the provided Block or the Dummy-Model MyQuery
	    elsif record['@class'].blank?
	      block_given? ? yield.new(record) : ActiveOrient::Model.orientdb_class(name: 'query' ).new( record )
	    else
		the_object = ActiveOrient::Model.orientdb_class(name: record['@class']).new record
		ActiveOrient::Base.store_rid( the_object )   # update cache
#	      end
	    end
	  end
	  # returns an array of updated objects
     
    rescue RestClient::BadRequest  => e
      #puts e.inspect
	  logger.error { "-"*30 }
	  logger.error { "REST_READ#GET_RECORDS.URL ---> Wrong Query" }
	  logger.error {  query.compose( destination: :rest).to_s }
	  logger.error { "Fired Statement: #{url.to_s} " }
	response=""
    rescue RestClient::InternalServerError => e
  	  response = JSON.parse(e.response)['errors'].pop
	  logger.error{ "Interbak Server ERROR" }
  	  logger.error{response['content'].split(':').last}
    rescue URI::InvalidURIError => e
  	  logger.error{"Invalid URI detected"}
  	  logger.error query.to_s
  	  logger.info{"Trying batch processing"}
  	  response = execute{ query.to_s}
  	  logger.info{"Success: to avoid this delay use ActiveOrient::Model#query_database instead"}
      response
    end
  end
  alias get_documents get_records

end
