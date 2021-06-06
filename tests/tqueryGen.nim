
# let bad_year = 1399
var q = mango:
  query:
    # @year != bad_year
    # @year mod [4,2]
    # ?= @genre or ?! @genre
    # @year is myStringVar
    # @year is bool and (((@year == 1 or @hamid == 4)))
    # not (@artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee"))
    # @artist == "mohammadAli" and (@genre notin ["pop", "rock"] or @artist == "iman khodaee")
    @list.size(3)
  
  fields: ["artist", "genre"]
  limit: 100

echo q.pretty
