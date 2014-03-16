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

    addName: (projectile) =>
        axisName = projectile.text().trim()
        nameToRemove = @axisName
        @axisName = axisName
        if nameToRemove isnt @axisName then [nameToRemove] else null

    getNames: =>
        return [@axisName]

    getTableDataHelper: (table, axisCandidates) =>
        data = ([@axisName].map (name) => table.columns[name])[0]
        if not data?
            @axisName = ""
        else
            isValid = axisCandidates.some (col) => col.name is data.name
            if not isValid
                data = undefined
                @axisName = "" 
        return data

    remove: (projectile) =>
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)
        target.removeClass("droppable-not-empty")
        @axisName = ""

    expand: () =>
        # Not allowed to expand

    contract: () =>
        # Not allowed to contract

