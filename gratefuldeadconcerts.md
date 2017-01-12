# Experiments with the GratefuldDeadConcterts database

First modify the database-entry (development) in /config/connect.yml to  «GreatfulDeadConerts».
This should be present after the installation of the database
Then execute « ./bin/active-orient-console d »
```
Present Classes (Hierarchy) 
  ---
  - - E
  - - followed_by
  - sung_by
  - written_by
  - V

  Active Classes  ->  ActiveOrient ClassName
  ---------------------------------------------
  V ->  V
  E ->  E
  followed_by ->  FollowedBy
  sung_by ->  SungBy
  written_by ->  WrittenBy
  ---------------------------------------------
```

Lets start with simple queries

* Select all vertices (or object) in the database

```ruby
V.all
```

* Select the vertex with the id #9:8
```ruby
V.autoload_object '#9:8'
```

* Select all the artists

```ruby
V.where type: 'artist'
```

*Select all the songs that have been performed  10 times 
** Display songnames and authors


```ruby
song_10 = V.where type: 'song', performances:  10
song_10.name
=> ["TOMORROW IS FOREVER", "SHE BELONGS TO ME", "UNBROKEN CHAIN"]
song_10.out_written_by.in.name 
=> [["Dolly_Parton"], ["Bob_Dylan"], ["Petersen"]]
```
*Select all the songs that have been performed  more or less 10 times 

```ruby
V.where "type = 'song’ and performances > 10"
V.where "type = 'song’ and performances < 10"
```
Count all songs and artists

```ruby
V.count where: { type: 'song' }
V.count where: { type: 'song', performances:  10 }

V.count where: { type: 'artist' }
```


* Find all songs sung by the first artist 
 
First get the artist
```ruby
 first_artist = OrientSupport::OrientQuery.new from: artist_vertex, where: { type: 'artist'} , limit: 1
 first_artist.to_s => "select  from V where type = 'artist'  limit 1"
```
Traverse through the database. List any song and author that is sung by this artist

```ruby
songs = DB.execute{ "select expand(set(in('sung_by'))) from (#{first_artist.to_s}) " }
songs.name
==> ["ROSA LEE MCFALL", "ROW JIMMY", "THAT WOULD BE SOMETHING", "BETTY AND DUPREE", "WHISKEY IN THE JAR", ...]

authors = DB.execute{ "select expand(set(in('sung_by').out('written_by'))) from (#{first_artist.to_s}) " }
authors.name
==>  ["Bob_Dylan", "Chuck_Berry", "Unknown", "Bernie_Casey_Pinkard", ...]

```



