module ActiveOrient
  class Batch < ActiveOrient::Model
    def initialize
      @transaction = true
      @operations = Array.new
    end
    attr_accessor :transaction

    def reset
      @operations.clear
    end

    def create record
      @operations << {"type" => "c", "record" => record}
    end

    def update record
      if record.has_key? "@rid"
        @operations << {"type" => "u", "record" => record}
      else
        logger.progname = 'ActiveOrient_Batch#Update'
        logger.error{"You need to specify a @rid."}
      end
    end

    def delete record
      if record.has_key? "@rid"
        @operations << {"type" => "d", "record" => record}
      else
        logger.progname = 'ActiveOrient_Batch#Update'
        logger.error{"You need to specify a @rid."}
      end
    end

    def command command, language = "sql"
      @operations << {"type" => "cmd", "language" => language, "command" => command}
    end

    def script script, language = "sql"
      @operations << {"type" => "scripts", "language" => language, "command" => command}
    end

    def to_json
      command = Hash.new
      command["transaction"] = @transaction
      command["operations"] = @operations
      command.to_json
    end
  end
end


# module ActiveOrient
#   class Batch < ActiveOrient::Model
#     def initialize
#       @transaction = true
#       @creationHash = {"type" => "c", "record" => Array.new}
#       @updateHash   = {"type" => "u", "record" => Array.new}
#       @deleteHash   = {"type" => "d", "record" => Array.new}
#       @commandHash  = {"type" => "cmd", "language" => "sql", "command" => Array.new}
#       @scriptHash   = {"type" => "scripts",  "language" => "javascript", "script" => Array.new}
#     end
#     attr_accessor :transaction
#
#     def reset value = nil
#       value.upcase! unless value.nil?
#       case value
#       when "CREATE", nil
#         @creationHash["record"].clear;
#       when "UPDATE", nil
#         @updateHash["record"].clear;
#       when "DELETE", nil
#         @deleteHash["record"].clear;
#       when "COMMAND", nil
#         @commandHash["command"].clear;
#       when "SCRIPT", nil
#         @scriptHash["script"].clear;
#       end
#     end
#
#     def create record
#       @creationHash["record"] << record
#     end
#
#     def update record
#       if record.has_key? "@rid"
#         @updateHash["record"] << record
#       else
#         logger.progname = 'ActiveOrient_Batch#Update'
#         logger.error{"You need to specify a @rid."}
#       end
#     end
#
#     def delete record
#       if record.has_key? "@rid"
#         @deleteHash["record"] << record
#       else
#         logger.progname = 'ActiveOrient_Batch#Update'
#         logger.error{"You need to specify a @rid."}
#       end
#     end
#
#     def command command, language = nil
#       unless language.nil?
#         @commandHash["language"] = "sql"
#       end
#       @commandHash["command"] << command
#     end
#
#     def script script, language = nil
#       unless language.nil?
#         @scriptHash["language"] = "sql"
#       end
#       @scriptHash["script"] << script
#     end
#
#     def to_json
#       command = Hash.new
#       command["transaction"] = @transaction
#       command["operations"] = Array.new
#       command["operations"] << @creationHash  unless @creationHash["record"].empty?
#       command["operations"] << @updateHash    unless @updateHash["record"].empty?
#       command["operations"] << @deleteHash    unless @deleteHash["record"].empty?
#       command["operations"] << @commandHash   unless @commandHash["command"].empty?
#       command["operations"] << @scriptHash    unless @scriptHash["script"].empty?
#       command.to_json
#     end
#   end
# end
