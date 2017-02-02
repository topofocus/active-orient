# Joining Tables 

The most important difference between OrientDB and a Relational Database is that relationships are represented by LINKS instead of JOINs.

For this reason, the classic JOIN syntax is not supported. OrientDB uses the "dot (.) notation" to navigate LINKS
(OrientDB-documation)

This supported by ActiveOrient in a very convient way.

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
 => 4


```




(to be continued)


