Changelog
=========
2020/11/27 : file: /lib/database_utils.rb
             method: system_classes,  OrientDB 3.1 compatibility
						 Added 'OSecurityPolicy' class to system-classes array 
             

2020/11/30 : file: /lib/model/the_class.rb
             method: require_model_file
						 The method now accepts an array of directories to be loaded

             Thus hierarchical class-structures are initialised properly.
						 It appeared that on reopening a base-class in a hierarchical structure
						 the contents were not read when accessing the child-classes. 

						 The change is backward compatible, the method accepts single directories as well.

2020/12/01   Ruby 2.7 (3.0) Compatibiltiy
             file: /lib/init.rb         ** Hash-notation as method parameter
						 file: /lib/model/the_record.rb   

2020/12/13   file /lib/other.rb
             method: Array#to_orient
						 If all members of the array respond to `rid?`  and any of them is a reference
						 to a database-record, put it without quotes into the serialized string.
						 This enables:  where: { contract: ['#194:0','208:0'] } => .in[ contract in [194:0, 208:0] ]
