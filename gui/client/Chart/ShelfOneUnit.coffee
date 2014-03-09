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

class ShelfOneUnit extends Shelf
    constructor: (args...) ->
        super args...

    addName: (projectile) =>
    	console.log "HERE"
    	axisName = projectile.text().trim()
    	namesToRemove = null
    	# Remove all names if this projectile has a different unit because the shelf can only have one unit
    	if @looseAcceptance and not projectile.hasClass(@looseAcceptance)
    		namesToRemove = @axisNames
    		@axisNames = [axisName]
    	else if @axisNames.indexOf(axisName) is -1 # no duplicates
            @axisNames.push axisName
        return namesToRemove
