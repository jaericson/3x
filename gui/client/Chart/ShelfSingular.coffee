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

class ShelfSingular extends Shelf
    constructor: (args...) ->
        super args...
        @axisName = @axisNames[0]

    addName: (axisName) =>
        oldAxisName = @axisName
        @axisName = axisName
        if oldAxisName isnt @axisName then oldAxisName else null

    getNames: =>
        return [@axisName]

    getVariables: (table) =>
        return ([@axisName].map (name) => table.columns[name])[0]

