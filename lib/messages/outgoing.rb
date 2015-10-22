#require 'lib/messages/outgoing/abstract'  in boot.rb

module OrientSupport
  module Messages
    module Outgoing
       extend Messages # def_message macros

             RequestConnect = OrientSupport::Messages::Outgoing.def_message(2, 
			      [:driver, 'ActiveOrient'],
			      [:driver_version, '1.0', :string ],
			      [:protocol,  30 ],
			      [:client_id, "0", :string ],
			      [:serialization, "ORecordSerializerBinary"],
			      [:token,  false],
			      [:user, :string ],
			      [:password, :string ])

	     # Request:
	     # (driver-name:string)(driver-version:string)(protocol-version:short)
	     # (client-id:string)(serialization-impl:string)(token-session:boolean)
	     # (database-name:string)(user-name:string)(user-password:string)
             RequestDBClose = OrientSupport::Messages::Outgoing.def_message(5 )

             RequestDBOpen = OrientSupport::Messages::Outgoing.def_message(3, 
			      [:driver, 'ActiveOrient'],
			      [:driver_version, '1.0', :string ],
			      [:protocol,  30 ],
			      [:client_id, "0", :string ],
			      [:serialization, "ORecordSerializerBinary"],
			      [:token,  true],
			      [:database, :string ],
			      [:type, 'document'],
			      [:user, :string ],
			      [:password, :string ])

             RequestDBExist = OrientSupport::Messages::Outgoing.def_message(6,
			      [:name, :string],
			      [:storage_type, :string] )
    end
  end
end
