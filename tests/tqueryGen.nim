import unittest, json
import mycouch/queryGen

template checkPJ(query, json: untyped): untyped = # checkPsOverJson
  check PS(query) == ( %* json)

suite "parse selector":
  test "not specefic search":
    checkPJ nil, {"_id": {"$gt": nil}}

  test "field name variants":
    let key = "fieldName"
    checkPJ key == 1, {"fieldName": {"$eq": 1}}

    checkPJ @id == 1, {"id": {"$eq": 1}}
    checkPJ @-id == 1, {"_id": {"$eq": 1}}
    checkPJ @"field.subField" == 1, {"field.subField": {"$eq": 1}}

  test "commmon comparition":
    checkPJ @year < 10, {"year": {"$lt": 10}}
    checkPJ @year <= 10, {"year": {"$lte": 10}}
    checkPJ @year == 10, {"year": {"$eq": 10}}
    checkPJ @year != 10, {"year": {"$ne": 10}}
    checkPJ @year >= 10, {"year": {"$gte": 10}}
    checkPJ @year > 10, {"year": {"$gt": 10}}

  test "value variant":
    let value = "someValue"
    checkPJ @field == "someValue", {"field": {"$eq": "someValue"}}
    checkPJ @field == value, {"field": {"$eq": value}}

  test "custom operators":
    checkPJ @field =~ "ali", {"field": {"$regex": "ali"}}

    checkPJ @field mod [4, 2], {"field": {"$mod": [4, 2]}}

    checkPJ @field in [2020, 2021], {"field": {"$in": [2020, 2021]}}
    checkPJ @field notin [2020, 2021], {"field": {"$nin": [2020, 2021]}}

    checkPJ ( ? @field), {"field": {"$eq": true}}
    checkPJ ( ! @field), {"field": {"$eq": false}}

    checkPJ ( ?= @field), {"field": {"$exists": true}}
    checkPJ ( ?! @field), {"field": {"$exists": false}}

    checkPJ @field is number, {"field": {"$type": "number"}}
    checkPJ @field is bool, {"field": {"$type": "boolean"}}
    checkPJ @field is string, {"field": {"$type": "string"}}
    checkPJ @field is object, {"field": {"$type": "object"}}
    checkPJ @field is array, {"field": {"$type": "array"}}
    checkPJ @field is nil, {"field": {"$type": "null"}}
    
    let myType = "other"
    checkPJ @field is myType, {"field": {"$type": "other"}}

  test "functions":
    let value = 4
    checkPJ @field.size(3), {"field": {"$size": 3}} # by literal
    checkPJ @field.size(value), {"field": {"$size": value}} # by value

    checkPJ @field.all(["v1", "v2"]), {"field": {"$all": ["v1", "v2"]}}
    checkPJ @field.keyMapMatch(["v1", "v2"]), {"field": {"$keyMapMatch": ["v1", "v2"]}}
    checkPJ @field.allMatch(["v1", "v2"]), {"field": {"$allMatch": ["v1", "v2"]}}
    checkPJ @field.elemMatch(["v1", "v2"]), {"field": {"$elemMatch": ["v1", "v2"]}}

  test "combinational operators":
    checkPJ not(@field == true), {"$not": {"field": {"$eq": true}}}

    checkPJ (@field1 == 1).nor(@field2 == 2), {"$nor": [
      {"field1": {"$eq": 1}},
      {"field2": {"$eq": 2}}
    ]}

    checkPJ @field1 == 1 or @field2 == 2, {"$or": [
      {"field1": {"$eq": 1}},
      {"field2": {"$eq": 2}}
    ]}

    checkPJ @field1 == 1 and @field2 == 2, {"$and": [
      {"field1": {"$eq": 1}},
      {"field2": {"$eq": 2}}
    ]}

  test "nested":
    checkPJ(
      not(@a != 1 and (@b notin ["2", 3] or @c == false)),
      {"$not": {
        "$and": [
          {"a": {"$ne": 1}},
          {"$or": [
              {"b": {"$nin": ["2", 3]}},
              {"c": {"$eq": false}},
          ]}
        ]
      }})
