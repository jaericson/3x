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

    addName: (projectile) =>
        axisName = projectile.text().trim()
        nameToRemove = if @axisNames[0]? then @axisNames[0] else null
        @axisNames[0] = axisName
        if nameToRemove isnt @axisNames[0] and nameToRemove? then [nameToRemove] else null

    getNames: =>
        # return if @axisNames.length is 0 then [undefined] else @axisNames[..] # copy of
        return @axisNames[..]

    getTableDataHelper: (table, axisCandidates) =>
        data = (@axisNames.map (name) => table.columns[name])[0]
        if not data?
            @axisNames = []
        else
            isValid = axisCandidates.some (col) => col.name is data.name
            if not isValid
                data = undefined
                @axisNames = []
        return data

    remove: (projectile) => 
        @target.removeClass("droppable-not-empty")
        if @isEssential then @target.addClass("droppable-empty")
        @axisNames = []

    expand: () =>
        # Not allowed to expand

    contract: () =>
        # Not allowed to contract

