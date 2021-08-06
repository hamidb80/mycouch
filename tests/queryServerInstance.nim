import json, tables, strutils
import mycouch/queryServer/[protocol, designDocuments]


proc testMap(doc: JsonNode): seq[JsonNode] {.mapfun.}= 
  # emit values like: [genre, movie_name]
  if ("title" in doc) and ("genres" in doc):
    for genre in doc["genres"]:
      emit(genre, doc["title"])

proc testReduce(keysNids: seq[JsonNode], values: seq[JsonNode], rereduce: bool): JsonNode {.redfun.}=
  ## group based on movies that a actress have in: [...movie_names]
  if rereduce:
    % newJNull()
  else:
    % values

proc `name-x2`(doc, req: JsonNode): tuple[newDoc, response: JsonNode] {.updatefun.}=
  doc["name"] = %(doc["name"].str.repeat(2) & req["body"].str)
  (
    doc, 
    %*{"body": "yay"}
  )

proc isWomen(doc, req: JsonNode): bool {.filterfun.}=
  doc["gender"].str == "female"

proc remainTheSameType(newDoc, oldDoc, req, sec: JsonNode) {.validatefun.}=
  if oldDoc.kind == JNull:
    if "type" notin newDoc:
      raise newException(Forbidden, "type field does not exist") 

  elif newDoc["type"].kind != oldDoc["type"].kind:
    raise newException(Forbidden, "not a specefic reason") 


when isMainModule:
  run()