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

## how to use:
  TODO