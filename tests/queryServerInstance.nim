import json, tables
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


when isMainModule:
  run()