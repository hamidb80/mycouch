# myCouch
  CouchDB client wrtten in Nim
  currently it's based on CouchDB `v3.1.1`

## mango query lang:
  ```nim
    mango(
      query: PS(@name == "hamid" and @year notin [1399])
      fields: ["name", "stars"]
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

### Usage:
TODO: show api doc link here

#### parse selector:
you can put the query im 2 ways: [`PS` is an alias for `parseSelector`]

- `PS( <query>  )`
- 
  ```
  PS:
    <query>
  ```

```nim
PS:
  # comparisions < <= == != >= >
  @year < bad_year            # year is a field
  name == "hamid"             # notice: name is a var name
  @`friend.name` == "ali"     # nested field

  @name =~ "ali"              # regex match | $regex
  @name =~ pat.pattern        # ""

  @year mod [4,2]             # modular | $mod

  @year in    [2020, 2021]    # in | $in
  @year notin [2020, 2021]    # not in | $nin

  ?= @genre or ?! @genre      # ?=: exists, ?! is not exists | $exists
  
  ? @genre or ! @genre        # ?: ==true, !: ==false
  
  @year is myType             # is for type spesification | $type
  @year is number               # object, array, string, number, nil, bool

  @list.size(3)               # match array len | $size
  @list.all(["hamid", "ali"]) # all function same for elemMatch, allMatch, keyMapMatch functions | $all 

  # or not | $and $or $not
  not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  (@field == 3 and @date == 12).nor(@field == 4) # since nim doesnt have 'nor' operator | $nor

```


## TODOs
 - [ ] add doc page
 - [ ] add test
 - [ ] add async
 - [ ] add response interfaces


## Notes
contributions are welcome :D