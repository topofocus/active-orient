# Joining Tables 

The most important difference between OrientDB and a Relational Database is that relationships are represented by LINKS instead of JOINs.

For this reason, the classic JOIN syntax is not supported. OrientDB uses the "dot (.) notation" to navigate LINKS
(OrientDB-documation)

This is supported by ActiveOrient in a very convient way.

Suppose, you want to store general Informations about a Company in a Class/Table called »the_base«. Then you want to keep records of available trading-instruments in a »asset« Class/Table, which should have children called »stock«, »optiton« or »bond«. Thus
```ruby
DB.create_vertex_class :the_base
DB.create_vertex_class :asset
DB.create_classes [ :stock, :option, :bond ]{ :asset }
```
The Asset-Class needs a property »base« which should carry an index. 
```ruby
Asset.create:property :base, type: link, index: :uniq
```
Both classes are initialized/assigned in a single statement
```ruby
Stock.create symbol: 'AAPL', base: TheBase.upsert( where: {name: 'Apple'} )
Bond.create maturity: Date.new(2025,5,31), cupon: 2.5 , base:  TheBase.upsert( where: {name: 'IBM'} )
```
Associated records are fetched the usual way
```ruby
google_assets =  Asset.where "base.name='Google'"
=> [#<Stock:0x000000035b8698 @metadata={"type"=>"d", "class"=>"stock", "version"=>3, "fieldTypes"=>"price=c,currency=x,base=x", "cluster"=>59, "record"=>336}, @attributes={"name"=>"GOOGLE INC-CL A", "ib_con_id"=>30351181, "price"=>555.19, "base"=>"#45:22"}>, 
#<Option:0x000000035a5598 @metadata={"type"=>"d", "class"=>"option", "version"=>3, "fieldTypes"=>"price=c,expire=t,currency=x,base=x", "cluster"=>65, "record"=>756}, @attributes={"name"=>"GOOGLE INC-CL A", "ib_con_id"=>nil, "price"=>5.2, "expire"=>"2014-08-29 00:00:00", "symbol"=>"GOOGL", "exchange"=>"SMART", "currency"=>"#42:0", "basiswert"=>"#45:22"} ] 
google_assets.asset.name 
=> ["Google", "Google"]
google_assets.name
=> ["GOOGLE INC-CL A"," "GOOGLE INC-CL A']
```

## Playing with Arrays and Linkmaps

Linkmaps are the OrientDB equivalent to joined tables 
Formally, they are ordinary arrays.

They can be created schemaless

```ruby
DB.create_class :industry
DB.create_class :property
property_record=  Property.create  con_id: 12346, property: []
industries =  ['Construction','HealthCare','Bevarage']
industries.each{| industry | property_record.property <<  Industry.create( label: industry ) }

Property.last
 => #<Property:0x00000001d1a938 @metadata={"type"=>"d", (...)},  
    @attributes={"con_id"=>12346, "property"=>["#34:0", "#35:0", "#36:0"],
    "created_at"=>"2017-02-01T06:28:17.332 01:00", "updated_at"=>"2017-02-01T06:28:17.344 01:00"}> 
 ```

Stored data in this array is accessible via

```ruby
p =  Property.last
p.property.label
 => ["Construction", "HealthCare", "Bevarage"]
p.property[2].label
 => "Bevarage" 
p.property.label[2]
  => "Bevarage" 
p.property[2].label[2]
 => "v" 

p.property.remove_at 2
p.property.label
  => ["Construction", "HealthCare"] 

p.property[2] = Industry.where(label:'Bevarage').first
p.property.label
 => ["Construction", "HealthCare", "Bevarage"] 
```

The Elements of the Array can be treated like common ruby Arrays. Manipulations are
performed in ruby-spac. Simply call
```ruby
p.update
```
to transfer the changes into the database. This approach can be extended to linked records as well

```ruby
p.property[2].label = 'zu'
p.property[2].update
p.property.label
 => ["Construction", "HealthCare", "zu"]
Industry.last.label
 => "zu"


```




(to be continued)


