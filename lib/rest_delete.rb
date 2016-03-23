module RestDelete

  ######### DATABASE ##########

  def delete_database database:
    @classes = []
    logger.progname = 'OrientDB#DropDatabase'
    old_ds = @database
    change_database database
    begin
  	  response = @res[database_uri].delete
  	  if database == old_ds
  	    change_database ""
  	    logger.info{"Working database deleted"}
  	  else
  	    change_database old_ds
  	    logger.info{"Database #{database} deleted, working database is still #{@database}"}
  	  end
    rescue RestClient::InternalServerError => e
      change_database old_ds
  	  logger.info{"Database #{database} NOT deleted, working database is still #{@database}"}
    end
    !response.nil? && response.code == 204 ? true : false
  end

  ######### CLASS ##########

  def delete_class o_class
    cl = classname(o_class)
    logger.progname = 'OrientDB#DeleteClass'
    if get_database_classes.include? cl
      begin
  	    response = @res[class_uri{cl}].delete
  	    logger.info{"Class #{cl} deleted."} if response.code == 204
      rescue RestClient::InternalServerError => e
  	    if get_database_classes(requery: true).include?(cl)
  	      logger.error{"Class #{cl} still present."}
  	      logger.error{e.inspect}
  	      false
  	    else
  	      true
  	    end
      end
    else
  	  logger.info{"Class #{cl} not present."}
    end
  end

  ############## RECORD #############

  def delete_record *rid
    logger.progname = "ActiveOrient::OrientDB#DeleteRecord"
    ridvec = []
    rid.each do |mm|
      if mm.is_a?(String)
  	    ridvec << mm if mm.rid?
      elsif mm.is_a?(Array)
        mm.each do |mmarr|
          ridvec << mmarr.rid if mmarr.is_a?(ActiveOrient::Model)
          ridvec << mmarr if mmarr.is_a?(String) && mmarr.rid?
        end
      elsif mm.is_a?(ActiveOrient::Model)
        ridvec << mm.rid
      end
    end
    ridvec.compact!

    unless ridvec.empty?
      ridvec.each do |rid|
        begin
          @res["/document/#{@database}/#{rid}"].delete
        rescue RestClient::InternalServerError
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

  def delete_records o_class, where: {}
    logger.progname = 'OrientDB#DeleteRecords'
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
    logger.progname = 'OrientDB#DeleteProperty'
    begin
  	  response = @res[property_uri(classname(o_class)){field}].delete
  	  true if response.code == 204
    rescue RestClient::InternalServerError => e
  	  logger.error{ "Property #{field} in  class #{classname(o_class)} NOT deleted" }
  	    false
    end
  end

end
