import json, sequtils
import mycouch/queryServer/[protocol, designDocuments]

proc testMap(doc: JsonNode): seq[JsonNode] {.mapfun.}= 
  # ## emit values like: [genre, movie_name]
  if ("title" in doc) and ("genres" in doc):
    for genre in doc["genres"]:
      emit(genre, doc["title"])


proc testReduce(mappedDocs: seq[JsonNode], rereduce: bool): JsonNode {.redfun.}=
  ## group based on movies that a actress have in: [...movie_names]
  % mappedDocs.mapIt it[1]


when isMainModule:
  run()