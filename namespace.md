## Namespace Support

Consider a project, where different tasks are clearly separated. 

A common case is, to concentrate any gathering of raw data in a separate module, maybe even in a gem.

ActiveOrient enables this by switching the "ActiveOrient::Model.namespace" directive.

### Activate Namespace

simply run
```
module HC
end
ActiveOrient::Init.define_namespace { HC }
```
to activate the namespace "HC" 

and 
```
ActiveOrient::Init.define_namespace { Object }```
```
to deactivate it.

### Extend ActiveOrient with a gem and introduce a namespace

In our case, the "ib-ruby" gem gets data through an api 
The gem provides the logic to convert the raw-data from the server to ActiveOrient::Model-Objects.
Its located in the model-directory of the gem.

Just by including the gem in the Gemfile and requiring it, anything is available in our project.

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

After row 80, the namspace is changed to "TG" (TimeGraph).  The example provides a gem as well. Just 
»require 'orientdb_time_graph'« and call »TG.connect« to include it properly.

The code above shows how to integrate the classes within the structure of the project. The difference is the placement
of the model-files. With the gem, they are located in the root-directory of the gem. The other approach looks in the model-directory of the project (model/tg).

Before we start, we  switch to the object-layer, where we want to define the working-classes. Their 
logic is defined in model-files in 'model'. And we want to make sure, that all database-classes are allocated
to ruby classes. 

```ruby
97   ActiveOrient::Init.define_namespace :object
98   ActiveOrient::Model.keep_models_without_file = true
99   ORD = ActiveOrient::OrientDB.new  preallocate: true
```

**note** The preallocation-algorithm trys to load any class. If »ActiveOrient::Model.keep_models_without_file«
is set to false, classes are allocated only, if a model-file is present. As a consequence, any appropopiate
model-file is loaded. 

Thus any previously allocated class can be extended, providing a proper model-file. For example: If we 
allocated a class «Contract« in the namspace »IB«, methods for this class are included from the model-dir specified in the gem *and* in the actual-model-directory ( in this case: model/ib/contract.rb ). 


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
change properties, include links and edges or to add  and remove classes in the Sub-Modules.

