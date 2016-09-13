shared Boolean eq(Anything a, Anything b)
    =>  if (exists a, exists b)
        then a == b
        else (!a exists) && (!b exists);