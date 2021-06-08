import json
import queryGen

# import nre, macros

let 
  # pat = re".*ali"
  bad_year = 1399
  name = "namesVar"
  myType = "string"

# var q = PS(@`friend.name` == "ali")
var q = PS:
  # @`friend.name` == "ali" 
  # @year != bad_year
  # name == "hamid"
  
  # @name =~ "ali"
  # @name =~ pat.pattern

  # @year mod [4,2]

  # ?? @genre or ?! @genre
  
  # @year is myType
  @year is number # object, array, string, number, nil, bool

  # @list.size(3)
  # @list.all(["hamid", "ali"])

  # not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  # (@field == 3 and @date == 12).nor(@field == 4)

echo q.pretty