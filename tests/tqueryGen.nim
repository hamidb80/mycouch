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
  # comparisions < <= == != >= >
  # @year < bad_year            # year is a field
  # name == "hamid"             # notice: name is a var name
  # @`friend.name` == "ali"     # nested field

  # @name =~ "ali"              # regex match | $regex
  # @name =~ pat.pattern        # ""

  # @year mod [4,2]             # modular | $mod

  # @year in    [2020, 2021]    # modular | $mod
  # @year notin [2020, 2021]    # modular | $mod

  # ?? @genre or ?! @genre      # ??: exists, ?! is not exists | $exists
  
  # @year is myType             # is for type spesification | $type
  # @year is number               # object, array, string, number, nil, bool

  # @list.size(3)               # match array len | $size
  # @list.all(["hamid", "ali"]) # all function same for elemMatch, allMatch, keyMapMatch functions | $all 

  # and or not | $and $or $not
  # not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
  
  # (@field == 3 and @date == 12).nor(@field == 4) # since nim doesnt have 'nor' operator | $nor

echo q.pretty