$ = require "jquery"
_ = require "underscore"
d3 = require "d3"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

class Shelf
    constructor: (@axisNames, @dropzoneIndex) ->
        # Sets above parameters
        @dropzoneClass = "dropzone"
        @heightIncrement = 30

    addName: (axisName) =>
        @axisNames.push axisName

        # increase height of target to accomodate more variables
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)
        h = target.height()
        target.css("height", (h + @heightIncrement))

        return null

    getNames: =>
        return @axisNames

    getVariables: (table) =>
        return @axisNames.map (name) => table.columns[name]

    positionOnShelf: (projectile, isDefault, animationTime) =>
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)

        projectile.data("droppedOnDropZone", true)
        projectile.addClass("isOnTarget")
        target.addClass("droppable-highlight")
        
        targetOffset     = target.offset()
        targetW          = target.outerWidth()
        targetH          = target.outerHeight()
        
        projectileOffset = projectile.offset()
        projectileW      = projectile.outerWidth()
        projectileH      = projectile.outerHeight()

        projectileLeft   = +projectile.css("left").replace("px", "")
        projectileTop    = +projectile.css("top").replace("px", "")

        centerOnTarget = (targetH / @axisNames.length - projectileH) / 2
        slotDownward = @heightIncrement * (@axisNames.length - 1)
        deltaY = projectileOffset.top - slotDownward - (targetOffset.top + centerOnTarget)
        
        centerOnTarget = (targetW - projectileW) / 2
        deltaX = projectileOffset.left - (targetOffset.left + centerOnTarget)
        deltaX -= 3 # -3 to account for left @ -6px in CSS

        newLeft = (projectileLeft - deltaX) + "px" 
        newTop = (projectileTop - deltaY) + "px"

        if isDefault
            projectile.css({
                left: newLeft
                top: newTop
                opacity: 1.0
            })
        else
            projectile.animate({
                    left: newLeft
                    top: newTop
                }, {
                duration: animationTime,
                specialEasing: {
                    left: "swing"
                    top: "swing"
                },
            })




       

