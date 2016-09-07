## Namespace Support

Consider a project, where different tasks are clearly separated. 

A common case is, to concentrate any gathering of raw data in a separate module, maybe even in a gem.

ActiveOrient enables this by switching the "ActiveOrient::Model.namespace" directive.

In out case, the "ib-ruby" gem gets data through an api 
The gem provides the logic to convert the raw-data from the server to ActiveOrient::Model-Objects.
Its located in the model-directory of the gem.

Just by including the gem in the Gemfile and requiring the gem, anything is available in our project.

The gem defines the ActiveOrient-Environment as follows:
```ruby
module IB                                
module ORD                             
include ActiveOrient::Init          # namespace support
mattr_accessor :login 

# establishes a connection to the Database and returns the Connection-Object (an ActiveOrient::OrientDB.         …instance)
def self.connect                  

  c = { :server => 'localhost', :port  => 2480,	:protocol => 'http',       
	:user   => 'root',   :password => 'root', :database => 'temp'  }.merge login.presence || {}
  ActiveOrient.default_server= { user: c[:user], password: c[:password] , server: c[:server], port: c[:port]  }
  ActiveOrient.database = c[:database]
  logger =  Logger.new '/dev/stdout'
  ActiveOrient::Init.define_namespace { IB } 
  project_root = File.expand_path('../..', __FILE__)

  ActiveOrient::Model.model_dir =  "#{project_root}/models"
  ActiveOrient::OrientDB.new  preallocate: true  # connect via http-rest

(...)
  ```
The gem scans through all database classes present, and allocates only those, where a model-file
is found in the model-directory. 

This takes place by requiring 'ib-ruby' in 'config/boot.rb'

```ruby
  76 #read the configuration and model-files from the ib-ruby gem directotry
  77 require 'ib/ord'
  78 IB::ORD.login= ActiveOrient.default_server.merge database: ActiveOrient.database
  79 require 'ib-ruby'  # automatically connects to the database
  80 
  81 # set the model-file for the time-graph
  82 module TG
  83 end
  84 ActiveOrient::Model.model_dir =  "#{project_root}/model"
  85 ActiveOrient::Init.define_namespace { TG }
  86 puts "Namespace changed: #{ActiveOrient::Model.namespace}"
  87 ActiveOrient::OrientDB.new  preallocate:  true

```

After row 80, the namspace is changed to "TG" (TimeGraph). This should provide a service to 
store data in a structured manner. The logic is defined in 'model/tg' located in our project-directory-tree.
Refer to the example-section to get some hints, what can be defined there.

At last, we have to switch to the object-layer, where we want to define the working-classes. Their 
logic is defined in model-files in 'model'.

```ruby
97   ActiveOrient::Init.define_namespace :object
98 
99   ORD = ActiveOrient::OrientDB.new  preallocate: true
```

As a result something like this appears:

```
DB-Class  -> Ruby-Object
		V ->  V
		E ->  E
contract ->  		IB::Contract
bag				->  IB::Bag
forex			->  IB::Forex
future			->  IB::Future
option			->  IB::Option
stock			->  IB::Stock
account			->  IB::Account
bar				->  IB::Bar
contract_detail ->  IB::ContractDetail
day_of	  ->  TG::DAY_OF
time_of	  ->  TG::TIME_OF
time_base ->  TG::TimeBase
monat	  ->  TG::Monat
stunde	  ->  TG::Stunde
tag	  ->  TG::Tag

new_test  ->  NewTest

```

By changing the namespace-scope with  'ActiveOrient::Init.define_namespace'  its always possible to 
change propeties, include links and edges or to add  and remove classes in the Sub-Modules.

