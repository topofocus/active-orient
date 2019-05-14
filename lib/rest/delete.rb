module RestDelete

  ######### DATABASE ##########

=begin
  Deletes the database and returns true on success
  After the removal of the database, the working-database might be empty
=end

  def delete_database database:
    logger.progname = 'RestDelete#DeleteDatabase'
    old_ds = ActiveOrient.database
    change_database database
    begin
		  response = nil
			ActiveOrient.db_pool.checkout do | conn |
				response = conn["/database/#{ActiveOrient.database}"].delete
			end
  	  if database == old_ds
  	    change_database  'temp'
  	    logger.info{"Working database deleted, switched to temp"}
  	  else
  	    change_database old_ds
  	    logger.info{"Database #{database} deleted, working database is still #{ActiveOrient.database}"}
  	  end
    rescue RestClient::InternalServerError => e
      change_database old_ds
  	  logger.info{"Database #{database} NOT deleted, working database is still #{ActiveOrient.database}"}
    end
    !response.nil? && response.code == 204 ? true : false
  end

  ######### CLASS ##########

=begin
	Deletes the specified class and returns true on success
todo: remove all instances of the class
=end

	def delete_class o_class
		cl = classname(o_class)
		return if cl.nil?
		logger.progname = 'RestDelete#DeleteClass'

		begin
			## to do: if cl contains special characters, enclose with backticks
			response = nil
			ActiveOrient.db_pool.checkout do | conn |
				response = conn["/class/#{ActiveOrient.database}/#{cl}"].delete
			end
			if response.code == 204
				logger.info{"Class #{cl} deleted."}

				ActiveOrient.database_classes.delete(cl)
			end
		rescue RestClient::InternalServerError => e
			sentence=  JSON.parse( e.response)['errors'].last['content']
			if ActiveOrient.database_classes.has_key? cl
				logger.error{"Class #{cl} still present."}
				logger.error{ sentence }
				false
			else
				logger.error{e.inspect}
				true
			end
		rescue Exception => e
			logger.error{e.message}
			logger.error{e.inspect}
		end
	end

  ############## RECORD #############

=begin
  Deletes a single Record when providing a single rid-link (#00:00) or a record
  Deletes multible Records when providing a list of rid-links or a record
  Todo: implement delete_edges after querying the database in one statement

  Example:
		ORD.create_class :test
		record =  Test.new  something: 'something' 
		ORD.delete_record record

		records= (1..100).map{|x| Test.create  something: x } 
		ORD.delete_record *records

  delete_records provides the removal of datasets after quering the database.
=end

  def delete_record *o
    logger.progname = "ActiveOrient::RestDelete#DeleteRecord"
		#o.map( &:to_orient ).map do |r|
		o.orient_flatten.map do |r|
			begin
				ActiveOrient::Base.remove_rid r 
#				rest_resource["/document/#{ActiveOrient.database}/#{r[1..-1].to_or}"].delete
				ActiveOrient.db_pool.checkout do | conn |
					conn["/document/#{ActiveOrient.database}/#{r.rid}"].delete
				end

			rescue RestClient::InternalServerError => e
				logger.error{"Record #{r} NOT deleted"}
			rescue RestClient::ResourceNotFound
				logger.error{"Record #{r} does not exist in the database"}
			rescue RestClient::BadRequest => e
				logger.error{"tried to delete RID: #{r[1..-1]}, but something went wrong"}
				logger.error e.inspect
			else
				logger.info{"Record #{r} deleted"}
			end
		end
	end
	alias delete_document delete_record

=begin
  Deletes records. They are defined by a query. All records which match the attributes are deleted.
  An Array with freed index-values is returned
=end

  def delete_records o_class, where: {}
    logger.progname = 'RestDelete#DeleteRecords'
    get_records(from: o_class, where: where).each{|y| delete_record  y}
  end
  alias delete_documents delete_records

  ################ PROPERTY #############

  def delete_property o_class, field
    logger.progname = 'RestDelete#DeleteProperty'
    begin
			response = ActiveOrient.db_pool.checkout do | conn |
				r =  conn["/property/#{ActiveOrient.database}/#{classname(o_class)}/#{field}"].delete
				true if r.code == 204
			end
    rescue RestClient::InternalServerError => e
  	  logger.error{"Property #{field} in  class #{classname(o_class)} NOT deleted" }
  	    false
    end
  end

end
