#require 'lib/messages/outgoing/abstract'  in boot.rb

module OrientSupport
  module Messages
    module Outgoing
       extend Messages # def_message macros

             RequestConnect = OrientSupport::Messages::Outgoing.def_message(2, [:driver, 'ActiveOrient'],
									    [:driver_version, '1.0', :string ],
									    [:protocol,  30 ],
									    [:client_id, "0", :string ],
									    [:serialization, "ORecordSerializerBinary"],
									    [:token,  false],
									    [:user, :string ],
									    [:password, :string ])
	    
    end
  end
end
