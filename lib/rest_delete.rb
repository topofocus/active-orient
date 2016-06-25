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
  	  response = @res["/database/#{ActiveOrient.database}"].delete
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
      response = @res["/class/#{ActiveOrient.database}/#{cl}"].delete
      if response.code == 204
	logger.info{"Class #{cl} deleted."}
	ActiveOrient.database_classes.delete(cl)
      end
    rescue RestClient::InternalServerError => e
      if get_database_classes(requery: true).include?(cl)
	logger.error{"Class #{cl} still present."}
	logger.error{e.inspect}
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
  record =  Vertex.create_document attributes: { something: 'something' }
  Vertex.delete_record record

  records= (1..100).map{|x| Vertex.create_document attributes: { something: x } }
  Vertex.delete_record *records

  delete_records provides the removal of datasets after quering the database.
=end

  def delete_record *rid
    logger.progname = "ActiveOrient::RestDelete#DeleteRecord"
    ridvec = []
    ridvec= rid.map( &:to_orient).flatten
    #    old code
#    do |mm|
#      case mm
#      when  String
#  	     mm if mm.rid?
#      when  Array
#        mm.map do |mmarr|
#	  if mmarr.is_a?(ActiveOrient::Model)
#           mmarr.rid   
#	   elsif mmarr.is_a?(String) && mmarr.rid?
#	     mmarr
#	   end
#        end.compact
#	when ActiveOrient::Model
#         mm.rid
#      end
#    end.flatten
    puts "RIDVEC"
    puts ridvec.inspect
#
    unless ridvec.empty?
      ridvec.each do |rid|
        begin
          @res["/document/#{ActiveOrient.database}/#{rid[1..-1]}"].delete
        rescue RestClient::InternalServerError => e
	  puts e.inspect
          logger.error{"Record #{rid} NOT deleted"}
        rescue RestClient::ResourceNotFound
          logger.error{"Record #{rid} does not exist in the database"}
        else
          logger.info{"Record #{rid} deleted"}
        end
      end
      return ridvec
    else
      logger.info{"No record deleted."}
      return nil
    end
  end
  alias delete_document delete_record
  alias delete_edge delete_record

=begin
  Deletes records. They are defined by a query. All records which match the attributes are deleted.
  An Array with freed index-values is returned
=end

  def delete_records o_class, where: {}
    logger.progname = 'RestDelete#DeleteRecords'
    records_to_delete = get_records(from: o_class, where: where)
    if records_to_delete.empty?
      logger.info{"No record found"}
    else
      delete_record records_to_delete
    end
  end
  alias delete_documents delete_records

  ################ PROPERTY #############

  def delete_property o_class, field
    logger.progname = 'RestDelete#DeleteProperty'
    begin
  	  response =   @res["/property/#{ActiveOrient.database}/#{classname(o_class)}/#{field}"].delete
  	  true if response.code == 204
    rescue RestClient::InternalServerError => e
  	  logger.error{"Property #{field} in  class #{classname(o_class)} NOT deleted" }
  	    false
    end
  end

end
