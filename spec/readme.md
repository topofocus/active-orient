# Prerequisites to run the specs


* Namespace support specs depend on a class structure which is read from 
  `/spec/etl`.  
  The test in `/spec/lib/namespace_create_spec.rb` will most likely fail.

> The etl-Files (*json) have to be customised!

```
>  "source": { "file": { "path": "/home/dev/activeorient/spec/etl/hy_hurra.csv" } },
    "extractor": { "csv": {} },
    "transformers": [
       { 
         "vertex": { "class": "hy_hurra" }
      } 
    ],
    "loader": {
       "orientdb": {
>         "serverUser": "hctw",
>         "serverPassword": "hc",
>         "dbUser": "hctw",
>         "dbPassword": "hc",
>         "dbURL": "remote:localhost/temp",
         "classes": [ 
          {"name": "hy_hurra", "extends": "V"}

```



> The location of `oetl.sh` is specified in `/spec/spec.yml`  

