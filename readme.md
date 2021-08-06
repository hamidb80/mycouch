# myCouch
CouchDB client wrtten in Nim.

currently it's based on CouchDB `v3.1.1`

**note:** deprecated & no-op APIs are not included

# APIs
**How can I know what `proc` for API should I use?**
1. you go to the CoudhDB documentation [link](http://docs.couchdb.org/en/3.1.1/api/) 
2. copy a API link (eg: `api/ddoc/render.html#db-design-design-doc-update-update-name`)
3. search that link in the `couchdb/api.nim` or [[github-page](https://hamidb80.github.io/mycouch/)]
4. you found the corresponding proc!

## Limitation
* copy APIs are not supported:
  1. [copy document](https://docs.couchdb.org/en/latest/api/document/common.html#copy--db-docid)
  2. [copy design document](https://docs.couchdb.org/en/latest/api/ddoc/common.html#copy--db-_design-ddoc)
* __continuous feed__ API are not supported in:
  1. [documents changes](https://docs.couchdb.org/en/latest/api/database/changes.html#get--db-_changes)
  2. [database changes](https://docs.couchdb.org/en/latest/api/server/common.html#db-updates)
* [cluster_setup](https://docs.couchdb.org/en/latest/api/server/common.html#cluster-setup) API is not available for now

**note**: examples are placed in `tests/tapi.nim`

# Features
## Mango Query-Lang
  ```nim
    mango(
      query= PS(@name == "hamid" and @year notin [1399])
      fields= @["name", "stars"]
    )
  ```
  converts to =>
  ```json
    {
      "selector" : {
        "$and": {
          "name": {
            "$eq": "hamid"
          },
          "year": {
            "$nin": [1399]
          }
        }
      },
      "fields": ["name", "stars"]
    }
  ```

### SQL-like Selector Parser
you can put the query im 2 ways: [`PS` is an alias for `parseSelector`]

- `PS( <query>  )`
- 
  ```
  PS:
    <query>
  ```

```nim
PS:
  nil                        # {"_id": {"$gt": nil}}
  
  # field name variants
  # since nim doesn't support underline at the first character of an identifier, you can use -
  field == true             # {"<THE VALUE OF VAR 'field'>": {"$eq": true}}
  @field == true            # {"field"                     : {"$eq": true}}
  @-field                   #  "_field" 
  @"_field._sub"            #  "_field._sub"

  # comparisions < <= == != >= >
  @year < bad_year            # 'year' is a field / 'bad_year' is var

  @name =~ "ali"              # regex match | $regex
  @name =~ pat.pattern        # ""

  @year mod [4,2]             # modular | $mod

  @year in    [2020, 2021]    # in | $in
  @year notin [2020, 2021]    # not in | $nin

  ?= @genre or ?! @genre      # (?=): exists, (?!): not exists | $exists
  
  ? @genre or ! @genre        # (?): == true, (!): == false
  
  @year is myType             # is for type spesification | $type
  @year is number             # object, array, string, number, nil, bool

  @list.size(3)               # match array len | $size
  @list.all(["hamid", "ali"]) # all function are the same for elemMatch, allMatch, keyMapMatch functions | $all 

  # or not | $and $or $not
  not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  (@field == 3 and @date == 12).nor(@field == 4) # since nim doesnt have 'nor' operator | $nor
```

## async + sync!
you can use all of APIs with your favourite runtime(did i use the right word?).

## Qeury Server
Do you remember some of [Erlang's built-in View functions](https://docs.couchdb.org/en/latest/ddocs/ddocs.html#built-in-reduce-functions)? 
here were gonna do something like that [but in nim]

we have 5 entry points:
  1. `mapfun`       -> map functions
  2. `redfun`       -> reduce functions
  3. `updatefun`    -> update 
  4. `filterfun`    -> filter
  5. `validatefun`  -> validate

each one are name of a macro that must be associated with corresponding `proc`.

every proc must be matched with it's corresponding pattern [you can see patterns in `mycouch/queryServer/designDocuments.nim`] otherwise you'll get an error.

here's an exmaple of proc `testMap` as an map function
```nim
import json, tables
import mycouch/queryServer/[protocol, designDocuments]

proc testMap(doc: JsonNode): seq[JsonNode] {.mapfun.}= 
  # emit values like: [genre, movie_name]
  if ("title" in doc) and ("genres" in doc):
    for genre in doc["genres"]:
      emit(genre, doc["title"])

when isMainModule:
  run()
```
**notes**:
* you can use quoted names for procs like \`my-pretty-view-function\`
* you have to import `tables` module wherever you define your entry procs
* don't forget to call `run` proc in your code! it starts the query server

compile that file and config the query server [doc](https://docs.couchdb.org/en/3.1.1/config/query-servers.html#query-servers-definition)

then you can create a design document with your query server: [design doc example for above code]
```json
{
    "_id": "_design/temp",
    "language": "<your-language-server-name>",
    "views": {
        "myview": {
            "map": "testMap"
        }
    }
}
```

done! your query server is ready!
[ examples with more details are placed in `tests/queryServerInstance.nim`]

# TODOs
 - [ ] update docs on gh-pages [you can `nimble gen docs` by yourself btw]
 - [ ] add docs for all modules
 - [ ] helper module
 - [ ] add test coverage tag

# Notes
contributions are welcome :D