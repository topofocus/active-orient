module RestChange

  ############### DATABASE ####################

  def change_database name
    @classes = []
    @database = name
  end

  ############# OBJECTS #################

  def update_records o_class, set:, where: {}
    url = "update #{classname(o_class)} set #{generate_sql_list(set)} #{compose_where(where)}"
    response = @res[URI.encode(command_sql_uri << url)].post ''
  end
  alias update_documents update_records

  def patch_record rid
    logger.progname = 'Rest#PatchRecord'
    content = yield
    if content.is_a? Hash
      begin
        @res[document_uri{rid}].patch content.to_orient.to_json
      rescue Exception => e
        logger.error{e.message}
      end
    else
  	  logger.error{"FAILED: The Block must provide an Hash with properties to be updated"}
    end
  end
  alias patch_document patch_record

end
