## apis like update withiout having rev ,...

import json
import api


proc getNupdate(self; rev:string, fn: proc(doc:JsonNode): JsonNode): bool

proc bulkDelete(self; docIds: seq[string])