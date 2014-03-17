$ = require "jquery"
_ = require "underscore"
d3 = require "d3"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

#TODO: hold onto the shelf instead of using a jQuery call to access it every time we need it?

class Shelf
    constructor: (@axisNames, @dropzoneIndex, @isEssential) ->
        # Sets above parameters
        @strictAcceptance = null
        @looseAcceptance = null
        @dropzoneClass = "dropzone"
        @topPaddingPlusMargin    = 0 + 4 # as specified in style.less
        @bottomPaddingPlusMargin = 4 + 4 # as specified in style.less
        @baseHeightPerProjectile = 16 # as specified in style.less
        @heightPerProjectile     = @baseHeightPerProjectile + @topPaddingPlusMargin + @bottomPaddingPlusMargin

    addName: (projectile) =>
        axisName = projectile.text().trim()
        if @axisNames.indexOf(axisName) is -1 # no duplicates
            @axisNames.push axisName
        return null

    getNames: =>
        return @axisNames[..] # copy of

    getTableData: (table, axisCandidates) =>
        # data for the specified axis names must be in the table and a valid axis candidate
        data = @getTableDataHelper table, axisCandidates
        # standardize no-units so that "undefined", "null", and an empty string all have empty string
        if data? then data[ord].unit = "" for ax,ord in data when data[ord]? and (not ax.unit? or not ax.unit.length? or ax.unit.length is 0)
        return data

    getTableDataHelper: (table, axisCandidates) =>
        data = @axisNames.map (name) => table.columns[name]
        data = data.filter (v) => v? # filter out any axisNames that the table cannot find
        data = data.filter (d) => axisCandidates.some (col) => col.name is d.name # filter out if not an axis candidate
        @axisNames = _.pluck(data, "name") # reset axisNames to only valid names
        return data

    wasCreated: =>
        @target = $(".#{@dropzoneClass}").eq(@dropzoneIndex)
        if @isEssential and @axisNames.length is 0 then @target.addClass("droppable-empty")

    strictlyAccept: (className) =>
        @strictAcceptance = className
        acceptingClass = ".projectile"
        acceptingClass += if @strictAcceptance? then ".#{@strictAcceptance}" else ""

        @target.droppable({
            accept: acceptingClass
        })

    looselyAccept: (className) =>
        @looseAcceptance = className

    add: (projectile, isDefaultNotDropped, animationTime) =>
        # increase height of @target to accomodate more variables
        if @isEssential then @target.removeClass("droppable-empty")
        @target.css("height", @baseHeightPerProjectile + @heightPerProjectile * (@axisNames.length - 1))
        @target.addClass("droppable-not-empty")

        projectile.addClass("isOnTarget")
        name = projectile.text().trim()
        index = @getNames().indexOf(name)

        if index is -1
            error "Can't find projectile name: #{name} as a shelf name" 
        
        @targetOffset     = @target.offset()
        @targetW          = @target.outerWidth()
        @targetH          = @target.outerHeight()
        
        projectileOffset = projectile.offset()
        projectileW      = projectile.outerWidth()
        projectileH      = projectile.outerHeight()

        projectileLeft   = +projectile.css("left").replace("px", "")
        projectileTop    = +projectile.css("top").replace("px", "")

        centerOnTarget = @topPaddingPlusMargin / 2
        slotDownward = @heightPerProjectile * index
        deltaY = projectileOffset.top - slotDownward - (@targetOffset.top + centerOnTarget)
        
        centerOnTarget = (@targetW - projectileW) / 2
        deltaX = projectileOffset.left - (@targetOffset.left + centerOnTarget)
        deltaX -= 2 # -2 to account for left @ -6px in CSS

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

    # used to temporarily expand when you're dragging an acceptable projectile
    expand: (projectile) =>
        # only expand if projectile isn't in this shelf's names AND has loose accepting class
        if not @looseAcceptance? or projectile.hasClass(@looseAcceptance)
            # only need to expand shelf if doesn't have this projectile
            if @getNames().indexOf(projectile.attr("data-name")) is -1
                @adjustHeight true

    # used to shrink back to fitted height after you're done dragging an acceptable projectile
    contract: (projectile) =>
        # only contract if has accepting class
        if not @looseAcceptance? or projectile.hasClass(@looseAcceptance)
            # only need to contract shelf if doesn't have this projectile
            # if @getNames().indexOf(projectile.attr("data-name")) is -1
                @adjustHeight false

    adjustHeight: (shouldExpand) =>
        inflated = if shouldExpand then 1 else 0
        numNames = _.max([@axisNames.length - 1 + inflated, 0])
        @target.css("height", @baseHeightPerProjectile + @heightPerProjectile * numNames)

        scale = if shouldExpand then 1 else -1

        # readjust projectiles
        for name, ix in @axisNames
            proj = $("div.projectile[data-name='#{name}']")
            top = +proj.css("top").replace("px", "")
            proj.css("top", top + scale * @heightPerProjectile)

    remove: (projectile) =>
        index = @axisNames.indexOf(projectile.attr("data-name"))
        @axisNames.splice index, 1

        # push projectiles up if after the index
        for name, ix in @axisNames
            if ix >= index
                proj = $("div.projectile[data-name='#{name}']")
                top = +proj.css("top").replace("px", "")
                console.log "Previous Top: #{top}; Move Down: #{@heightPerProjectile}; New Top: #{top - @heightPerProjectile}"
                proj.css("top", top - @heightPerProjectile)

        # if shelf empty, then remove not-empty class
        if @axisNames.length is 0
            @target.removeClass("droppable-not-empty")
            if @isEssential then @target.addClass("droppable-empty")
        else
            @target.css("height", @baseHeightPerProjectile + @heightPerProjectile * (@axisNames.length - 1))




       

