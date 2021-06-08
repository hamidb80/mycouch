# myCouch
  CouchDB client wrtten in Nim

## mango query lang:
  ```nim
    mango:
      query: @name == "hamid" and @year notin [1399]
      fields: ["name", "stars"]
  ```

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

```nim
mango:
  @`friend.name` == "ali" 
  @year != bad_year
  name == "hamid"

  @name =~ "ali"
  @name =~ pat.pattern
  
  @year mod [4,2]
  ?? @genre or ?! @genre

  @year is myType
  @year is number # object, array, string, number, nil, bool
  @list.size(3)
  @list.all(["hamid", "ali"])
  not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  (@field == 3 and @date == 12).nor(@field == 4)
```