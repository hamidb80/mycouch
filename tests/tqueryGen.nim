import json, macros

# dumpTree:
#   ?? @genre or ?! @genre

let 
  bad_year = 1399
  name = "namesVar"
# var q = PS(@`friend.name` == "ali")

import queryGen

var q = PS:
  # @`friend.name` == "ali" 
  # name == "dsa"
  # @year != bad_year
  # @year mod [4,2]
  # ?! @genre
  ?? @genre or ?! @genre
  # @year is myStringVar
  # @year is bool and (((@year == 1 or @hamid == 4)))
  # not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  # @artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee")
  # @list.size(3)

echo q.pretty