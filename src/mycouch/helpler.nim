## apis like update withiout having rev ,...

import json
import api

# wrappers -----------------------------------------------------------

template TryIfErrorOccored(tryAgainPred, body: untyped): untyped

template authCheck(attempts = 2, body: untyped): untyped

# functionalities ----------------------------------------------------

proc bulkDelete(self; docIds: seq[string])

proc updateById(self, docid, newDoc: JsonNode)

proc getNupdate(self; rev: string, fn: proc(doc: JsonNode): JsonNode): bool

proc deleteById(self, docid)

