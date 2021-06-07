import json
import queryGen
import macros

dumpTree:
  @`friend.name` == "ali"

# let bad_year = 1399
# var q = PS(@`friend.name` == "ali")
var q = PS:
  @`friend.name` == "ali" 
  # @year != bad_year
  # @year mod [4,2]
  # ?= @genre or ?! @genre
  # @year is myStringVar
  # @year is bool and (((@year == 1 or @hamid == 4)))
  # not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  # @artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee")
  # @list.size(3)

echo q.pretty