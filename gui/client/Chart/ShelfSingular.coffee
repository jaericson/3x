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
        nameToRemove = @axisName
        @axisName = axisName
        if nameToRemove isnt @axisName then nameToRemove else null

    getNames: =>
        return [@axisName]

    getVariables: (table) =>
        return ([@axisName].map (name) => table.columns[name])[0]

    remove: (projectile) =>
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)
        target.removeClass("droppable-not-empty")

        @axisName = ""

    expand: () =>
        # Not allowed to expand

    contract: () =>
        # Not allowed to contract

