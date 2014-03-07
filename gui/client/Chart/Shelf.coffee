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
        @topPaddingPlusMargin    = 0 + 4 # as specified in style.less
        @bottomPaddingPlusMargin = 4 + 4 # as specified in style.less
        @baseHeightPerProjectile = 16 # as specified in style.less
        @heightPerProjectile     = @baseHeightPerProjectile + @topPaddingPlusMargin + @bottomPaddingPlusMargin

    addName: (axisName) =>
        @axisNames.push axisName
        return null

    getNames: =>
        return @axisNames

    getVariables: (table) =>
        return @axisNames.map (name) => table.columns[name]

    defineAcceptance: (acceptingClass) =>
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)
        target.droppable({
            accept: acceptingClass
        })

    add: (projectile, isDefaultNotDropped, animationTime) =>
        # increase height of target to accomodate more variables
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)
        target.css("height", @baseHeightPerProjectile + @heightPerProjectile * (@axisNames.length - 1))
        target.addClass("droppable-not-empty")

        projectile.addClass("isOnTarget")
        name = projectile.text().trim()
        index = @getNames().indexOf(name)

        if index is -1
            error "Can't find projectile name: #{name} as a shelf name" 
        
        targetOffset     = target.offset()
        targetW          = target.outerWidth()
        targetH          = target.outerHeight()
        
        projectileOffset = projectile.offset()
        projectileW      = projectile.outerWidth()
        projectileH      = projectile.outerHeight()

        projectileLeft   = +projectile.css("left").replace("px", "")
        projectileTop    = +projectile.css("top").replace("px", "")

        centerOnTarget = (targetH / @axisNames.length - projectileH) / 2
        slotDownward = @heightPerProjectile * index
        deltaY = projectileOffset.top - slotDownward - (targetOffset.top + centerOnTarget)
        
        centerOnTarget = (targetW - projectileW) / 2
        deltaX = projectileOffset.left - (targetOffset.left + centerOnTarget)
        deltaX -= 3 # -3 to account for left @ -6px in CSS

        newLeft = (projectileLeft - deltaX) + "px" 
        newTop = (projectileTop - deltaY) + "px"

        if isDefaultNotDropped
            projectile.css({
                left: newLeft
                top: newTop
                opacity: 1.0
            })
        else
            projectile.data("droppedOnDropZone", true)
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

    remove: (projectile) =>
        target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)

        index = @axisNames.indexOf(projectile.attr("data-name"))
        @axisNames.splice index, 1

        # push projectiles up if after the index
        for name, ix in @axisNames
            if ix >= index
                proj = $("div.projectile[data-name='#{name}']")
                top = +proj.css("top").replace("px", "")
                proj.css("top", top - @heightPerProjectile)

        # if shelf empty, then remove not-empty class
        if @axisNames.length == 0
            target.removeClass("droppable-not-empty")
        else
            target.css("height", @baseHeightPerProjectile + @heightPerProjectile * (@axisNames.length - 1))





       

