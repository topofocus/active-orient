module RestRead

  ############# DATABASE #############

# Returns an Array with available Database-Names as Elements
#
#    ORD.get_databases
#     => ["temp", "GratefulDeadConcerts", (...)] 
  def get_databases
    JSON.parse(@res["/listDatabases"].get.body)['databases']
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
    	response = @res["/database/#{ActiveOrient.database}"].get
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
    JSON.parse(@res["/class/#{ActiveOrient.database}/#{classname(o_class)}"].get)
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
=end

  def get_record rid
    begin
      logger.progname = 'RestRead#GetRecord'
      if rid.rid?
	response = @res["/document/#{ActiveOrient.database}/#{rid.to_orient[1..-1]}"].get
	raw_data = JSON.parse(response.body) 
	ActiveOrient::Model.orientdb_class(name: raw_data['@class'], superclass: :find_ME).new raw_data
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
      logger.error { "No data found" }
      logger.error { "The command: \"/document/#{ActiveOrient.database}/#{rid.to_orient}\" "}
      logger.error { "The response: #{e.message }"}
    rescue Exception => e
      logger.error { "Something went wrong" }
      logger.error { "RID: #{rid} - #{e.message}" }
    end
  end
  alias get_document get_record

=begin
Retrieves Records from a query

If raw is specified, the JSON-Array is returned, e.g.
    {"@type"=>"d", "@rid"=>"#15:1", "@version"=>1,    "@class"=>"DocumebntKlasse10", "con_id"=>343, "symbol"=>"EWTZ"}

Otherwise a ActiveModel-Instance is created and returned
=end

  def get_records raw: false, query: nil, **args
    query = OrientSupport::OrientQuery.new(args) if query.nil?
    begin
      logger.progname = 'RestRead#GetRecords'
  	  url = "/query/#{ActiveOrient.database}/sql/" + query.compose(destination: :rest) + "/#{query.get_limit}"
#	  puts "REST_READ#GET_RECORDS.URL"
#	  puts "ARGS: #{args.inspect}"
#	  puts query.compose( destination: :rest).to_s
#	  puts url.to_s
  	  response = @res[URI.encode(url)].get
	  JSON.parse(response.body)['result'].map do |record|
	    if raw
	      record
	      # query returns an anonymus class: Use the provided Block or the Dummy-Model MyQuery
	    elsif record['@class'].blank?
#	      puts "RECORD:\n"+record.inspect
	      block_given? ? yield.new(record) : ActiveOrient::Model.orientdb_class(name: 'query' ).new( record )
	    else
	      ActiveOrient::Model.orientdb_class(name: record['@class'], superclass: :find_ME).new record
	    end
	  end
	  # returns the JSON-Object
     

    rescue RestClient::InternalServerError => e
  	  response = JSON.parse(e.response)['errors'].pop
	  logger.error{ "Interbak Server ERROR" }
  	  logger.error{response['content'].split(':').last}
    rescue URI::InvalidURIError => e
  	  logger.error{"Invalid URI detected"}
  	  logger.error query.to_s
  	  logger.info{"Trying batch processing"}
  	  sql_cmd = -> (command){{type: "cmd", language: "sql", command: command}}
  	  response = execute{[sql_cmd[query.to_s]]}
  	  logger.info{"Success: to avoid this delay use ActiveOrient::Model#query_database instead"}
      response
    end
  end
  alias get_documents get_records

end
