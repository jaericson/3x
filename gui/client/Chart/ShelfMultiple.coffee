$ = require "jquery"
_ = require "underscore"
d3 = require "d3"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"
Shelf = require "Shelf"

class ShelfMultiple extends Shelf
    constructor: (args...) ->
        super args...
