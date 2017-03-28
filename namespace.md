## Namespace Support

Consider a project, where different tasks are clearly separated. 

A common case is, to concentrate any gathering of raw data in a separate module, maybe even in a gem.

ActiveOrient enables this by switching the »ActiveOrient::Model.namespace« directive.

### The Default Case

Databsase-Classes are mapped to the Object-Layer

```ruby
ActiveOrient::Init.define_namespace namespace: :object  
```


### Activate Namespace

to activate the namespace "HC" simply run

```ruby
module HC
end
ActiveOrient::Init.define_namespace { HC }
```
and 

to deactivate it.

### Prefixed Classnames to Avoid Ambiguous Identifiers

OrientDB-Classnames follow a class-hierarchy but namespacing is not implementated. Thus we are mocking a 
rudimentary Namespace-Support through prefixing.

ActiveOrient::Model.namespace_prefix translates a single namespace into a database-prefix:

```ruby
ActiveOrient::Init.define_namespace namespace: :object
ActiveOrient::Model.keep_models_without_file = true
ORD = ActiveOrient::OrientDB.new  preallocate: true
ActiveOrient::Init.define_namespace { HH  }
ActiveOrient::OrientDB.new  preallocate: true
ActiveOrient::Init.define_namespace { HY }
ActiveOrient::OrientDB.new  preallocate: true
```
**note** The preallocation-algorithm tries to load any class.  If the classes "tg_hui, ib_hui, hui" are
present, "TgHui,IbHui,Hui" are created during the basic initialisation of ActiveOrientDB (Namespace: Object). 
If »ActiveOrient::Model.keep_models_without_file«
is set to false, classes are allocated only, if a model-file is present. 


As a result something like this appears:

```
---------------------------------------------
Database Class  ->  ActiveOrient Class
---------------------------------------------
              E ->  E
              V ->  V
  hh_hipp_hurra ->  HH::HippHurra
       hh_hurra ->  HH::Hurra
     hipp_hurra ->  HippHurra
          hurra ->  Hurra
  hy_hipp_hurra ->  HY::HippHurra
       hy_hurra ->  HY::Hurra
---------------------------------------------

```

By changing the namespace-scope with  'ActiveOrient::Init.define_namespace'  its always possible to 
change properties, include links and edges or to add  and remove classes in the Sub-Modules.

ORD.create_class "hurry" creates a Ruby-Class »HH::Hurry« and a DatabaseClass »hh_hurry«.
This can be changed through redefinition of »ActiveOrient::Model.namespace_prefix«

```ruby
## Deactivate Namespace-Prefix
class ActiveOrient::Model
  def self.namespace_prefix
  ""
  end
end
```

### Extend ActiveOrient with a gem  using namespacing

A Gem usually defines its own logic how to deal with database-entries. This is backed by 
customized model-classes, which are located somewhere in the dir-structure of the gem.
The Gem should therefor read these files during initialisation. 

A blueprint:

```ruby
module IB
  module OrientDB
  
  
    # establishes a connection to the Database and allocates database-classes according
    # to moddelfiles present in the specified model-directory
    def self.connect 
    
      IB::Gateway.logger = ActiveOrient::Base.logger
       ActiveOrient::Init.define_namespace { IB } 
       project_root = File.expand_path('../..', __FILE__)
 
       ActiveOrient::OrientDB.new  preallocate: true , model_dir:  "#{project_root}/models"
  
     end
  
   end # module DB
 end

```

In »config/boot.rb« we just call

```ruby
require 'ib-ruby'
ActiveOrient::Init.define_namespace namespace: :object
ActiveOrient::Model.keep_models_without_file = true
ORD = ActiveOrient::OrientDB.new  preallocate: true
IB::OrientDB.connect
```

To start, we switch to the object-layer and initialize E and V. 

Then we let the gem do the job of assigning database-classes to ruby-model-classes



