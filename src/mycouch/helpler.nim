## apis like update withiout having rev ,...

import json
import api

template TryIfErrorOccored(tryAgainPred, body: untyped): untyped

template authCheck(attempts = 2, body: untyped): untyped


proc getNupdate(self; rev: string, fn: proc(doc: JsonNode): JsonNode): bool

proc bulkDelete(self; docIds: seq[string])