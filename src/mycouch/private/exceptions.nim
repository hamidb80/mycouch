import httpcore, json

type 
  CouchDBError* = object of Defect
    responseCode*: HttpCode
    info*: JsonNode

func newCouchDBError*(respCode: HttpCode, info: JsonNode): ref CouchDBError=
  result = newException(CouchDBError, "")
  result.responseCode = respCode
  result.info = info
  