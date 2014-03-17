$ = require "jquery"
_ = require "underscore"
d3 = require "d3"
require "jsrender"
require "jquery.ui.droppable"
require "jquery.ui.draggable"
require "jquery.ui.effect"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

CompositeElement = require "CompositeElement"
ChartData = require "ChartData"
Chart = require "Chart"
BarChart = require "BarChart"
ScatterPlot = require "ScatterPlot"
LineChart = require "LineChart"
Shelf = require "Shelf"
ShelfSingular = require "ShelfSingular"
ShelfMultiple = require "ShelfMultiple"
ShelfOneUnit = require "ShelfOneUnit"

class ChartView extends CompositeElement
    constructor: (@baseElement, @typeSelection, @table, @optionElements = {}) ->
        super @baseElement

        # use local storage to remember previous chart type
        @chartType = try JSON.parse localStorage["chartType"]

        @typeSelection.on("click", ".chart-type-li", @actionHandlerForChartTypeControl @handleChartTypeChange)
        @table.on "changed", @initializeAxes
        @table.on "updated", @display

        @optionElements.chartOptionsPlainText.find("#change-settings-button").on("click", (e) =>
            @showInteractiveMode true
            do @initializeAxes true
        )

        # if user resizes window, call display at most once every 100 ms
        $(window).resize(_.throttle @display, 100)

        # hide all popover when not clicked on one
        $('html').on("click", (e) =>
            if $(e.target).closest(".dot, .popover").length is 0
                @baseElement.find(".dot").popover("hide")
            if $(e.target).closest(".databar, .popover").length is 0
                @baseElement.find(".databar").popover("hide")
        )
        # enable nested popover on-demand
        @baseElement.on("click", ".popover [data-toggle='popover']", (e) =>
            $(e.target).closest("[data-toggle='popover']").popover("show")
        )

        # vocabularies for option persistence
        @chartOptions = (try JSON.parse localStorage["chartOptions"]) ? {}
        persistOptions = => localStorage["chartOptions"] = JSON.stringify @chartOptions
        optionToggleHandler = (e) =>
            btn = $(e.target).closest(".btn")
            return e.preventDefault() if btn.hasClass("disabled")
            chartOption = btn.attr("data-toggle-option")
            @chartOptions[chartOption] = not btn.hasClass("active")
            do persistOptions
            do @display
        # vocabs for installing toggle handler to buttons
        installToggleHandler = (chartOption, btn) =>
            return btn
               ?.toggleClass("active", @chartOptions[chartOption] ? false)
                .attr("data-toggle-option", chartOption)
                .click(optionToggleHandler)
        # vocabularies for axis options
        forEachAxisOptionElement = (prefix, chartOptionPrefix, job) =>
            for axisName in @constructor.AXIS_NAMES
                optionKey = chartOptionPrefix + axisName
                job optionKey, @optionElements["#{prefix}#{axisName}"], axisName

        installToggleHandler "interpolateLines", @optionElements.toggleInterpolateLines
        installToggleHandler "hideLines",        @optionElements.toggleHideLines
        # log scale
        @optionElements.toggleLogScale =
            $(forEachAxisOptionElement "toggleLogScale", "logScale", installToggleHandler)
                .toggleClass("disabled", true)
        # origin
        @optionElements.toggleOrigin =
            $(forEachAxisOptionElement "toggleOrigin", "origin", installToggleHandler)
                .toggleClass("disabled", true)
        
        @animationTime = 150
        
        # mouseover to display projectiles
        @optionElements.chartOptionsContainer.find("#chart-options-dropzones").on("mouseover", (e) =>
            target = $(e.target)
            left = target.closest(".btn-group").offset().left
            top = target.closest(".btn-group").offset().top + target.closest(".btn-group").outerHeight()

            # this is a little hacky
            @showProjectiles left, top, target.parents(".btn-group").next(".dropzone").outerHeight()
        )

        @optionElements.chartOptionsContainer.find("#chart-options-projectile-dismissal").on("click", (e) => do @hideProjectiles)

    @AXIS_NAMES: "X Y".trim().split(/\s+/)

    persist: =>
        localStorage["shelfX"] = JSON.stringify @shelves.X.getNames()
        localStorage["shelfY"] = JSON.stringify @shelves.Y.getNames()
        localStorage["shelfPivot"] = JSON.stringify @shelves.PIVOT.getNames()
        localStorage["shelfSmult"] = JSON.stringify @shelves.SMULT.getNames()
        localStorage["chartType"] = JSON.stringify @chartType

    # axis change dropdown HTML skeleton
    @AXIS_PICK_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
          <div data-order="{{>ord}}" class="axis-control axis-change btn-group">
            <a class="btn btn-small dropdown-toggle" data-toggle="dropdown"
              href="#"><span class="axis-name">{{>axis.name}}</span>
                  <span class="caret"></span></a>
            <ul class="dropdown-menu" role="menu" aria-labelledby="dLabel">
              {{for variables}}
                <li class="axis-var" data-name="{{>name}}"><a href="#"><i
                    class="icon icon-{{if isMeasured}}dashboard{{else}}tasks{{/if}}"></i>
                        {{>name}}</a></li>
              {{/for}}
              {{if isOptional}}
                {{if variables.length > 0}}<li class="divider"></li>{{/if}}
                <li class="axis-remove"><a href="#"><i class="icon icon-remove"></i> Remove</a></li>
              {{/if}}
            </ul>
          </div>
        </script>
        """)

    # axis add dropdown HTML skeleton
    @AXIS_ADD_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
          <div class="axis-control axis-add btn-group">
            <a class="btn btn-small dropdown-toggle" data-toggle="dropdown"
              href="#">… <span class="caret"></span></a>
            <ul class="dropdown-menu" role="menu" aria-labelledby="dLabel">
              {{for variables}}
                <li class="axis-var" data-name="{{>name}}"><a href="#"><i
                    class="icon icon-{{if isMeasured}}dashboard{{else}}tasks{{/if}}"></i>
                    {{>name}}</a></li>
              {{/for}}
            </ul>
          </div>
        </script>
        """)

    @CHART_PICK_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
            {{for names}}
                <li class="chart-type-li"><a href="#"><i class="icon icon-signal"></i> {{>#data}}</a></li>
            {{/for}}
        </script>
        """)

    @PROJECTILE_OPTION: $("""
        <script type="text/x-jsrender">
            {{for variables}}
                <div class="chart-options-moveme unit-{{>unit}} projectile{{if isRatio}} ratioVariable{{/if}}" data-name="{{>name}}">
                    <i class="icon icon-{{if isMeasured}}dashboard{{else}}tasks{{/if}}"></i> {{>name}}</div>

            {{/for}}
        </script>
        """)

    # <div>
    # {{>name}}=
    #     <span class="dropzone" style="width:{{>width}}px">...</span>
    #         </div>
    @TARGET_OPTION: $("""
        <script type="text/x-jsrender">
            {{for variables}}
                <div class="btn-group" style="float:left" >
                    <a class="btn btn-small dropdown-toggle axis-picker-btn" data-toggle="dropdown">
                        <span class="caret"></span>
                        <span>{{>name}}</span>
                    </a>
                    <ul class="dropdown-menu">
                        <li><a href="#">Option 1</a></li>
                        <li><a href="#">Option 2</a></li>
                    </ul>
                </div>
                <div class="dropzone" data-order="{{>ord}}" style="width:{{>width}}px"></div>
            {{/for}}
        </script>
        """)

    actionHandlerForChartTypeControl: (action) => (e) =>
        e.preventDefault()
        $this = $(e.target)
        $axisControl = $this.closest("#chart-type")
        name = $this.closest("a").text()
        action name, $axisControl, $this, e

    handleChartTypeChange: (name, $axisControl) =>
        $axisControl.find(".chart-name").text(name)
        @chartType = name.trim()
        @chartOptions.justChanged = "chartType"
        do @persist
        do @initializeAxes true

    actionHandlerForAxisControl: (action) => (e) =>
        e.preventDefault()
        $this = $(e.target)
        $axisControl = $this.closest(".axis-control")
        ord = +$axisControl.attr("data-order")
        name = $this.closest(".axis-var").attr("data-name")
        action ord, name, $axisControl, $this, e

    @Y_AXIS_ORDINAL: 0 # first variable is Y
    @X_AXIS_ORDINAL: 1 # second variable is X
    @PIVOT_AXIS: 2
    @SMULT_AXIS: 3
    @ORD_TO_AXIS_SHELF: ["Y", "X", "PIVOT", "SMULT"]
    @ORD_TO_AXIS_NAME: ["Y", "X", "Pivot", "Small Multiple"]
    
    # initialize @axes from @shelves (which is saved in local storage)
    initializeAxes: (redrawProjectiles) => 
        if @table.deferredDisplay?
            do @table.render # XXX charting heavily depends on the rendered table, so force rendering
        return unless @table.columnsRendered?.length
        # collect candidate variables for chart axes from ResultsTable
        axisCandidates =
            # only the expanded input variables (usually a condition) or output variables (usually measurement) can be charted
            # below logic will add to the axis candidates any expanded input variable or any rendered measured output variable
            # columns are not rendered if they are unchecked in the left-hand panel
            (col for col in @table.columnsRendered when col.isExpanded or col.isMeasured)
        axisCandidates[ord].unit = "" for ax,ord in axisCandidates when not ax.unit? or not ax.unit.length? or ax.unit.length is 0
        nominalVariables =
            (axisCand for axisCand in axisCandidates when utils.isNominal axisCand.type)
        ratioVariables =
            (axisCand for axisCand in axisCandidates when utils.isRatio axisCand.type)
        # check if there are enough variables to construct a two-dimensional chart: if so, add toggle buttons on RHS, if not, show a message
        canDrawChart = (possible) =>
            @baseElement.add(@optionElements.chartOptionsContainer).toggleClass("hide", not possible)
            @optionElements.alertChartImpossible?.toggleClass("hide", possible)
        # we need at least 1 ratio variable and 2 variables total
        if ratioVariables.length >= 1 and nominalVariables.length + ratioVariables.length >= 2
            canDrawChart yes
        else
            canDrawChart no
            return

        cachedX = try JSON.parse localStorage["shelfX"]
        cachedX?= [nominalVariables[0]?.name ? ratioVariables[1]?.name]
        cachedY = try JSON.parse localStorage["shelfY"]
        cachedY?= [ratioVariables[0]?.name ? ratioVariables[0]?.name]
        cachedPivot = try JSON.parse localStorage["shelfPivot"]
        cachedPivot?= []
        cachedSmult = try JSON.parse localStorage["shelfSmult"]
        cachedSmult?= []

        @shelves?=
            "Y": new ShelfOneUnit cachedY, 0, true
            "X": new ShelfSingular cachedX, 1, true
            "PIVOT": new ShelfMultiple cachedPivot, 2, false
            "SMULT": new ShelfMultiple cachedSmult, 3, false

        @varX = @shelves.X.getTableData @table, axisCandidates
        @varsY = @shelves.Y.getTableData @table, axisCandidates
        @varsPivot = @shelves.PIVOT.getTableData @table, axisCandidates
        @varsSmult = @shelves.SMULT.getTableData @table, axisCandidates

        chartTypes = "Line Bar".trim().split(/\s+/)
        noSpecifiedChartType = not @chartType?
        # specify which chart types are allowed
        if @varX? and utils.isRatio @varX.type
            chartTypes.push "Scatter"
            # Keep it a scatterplot
            @chartType = "Scatter" if noSpecifiedChartType or @chartOptions.justChanged is "x-axis"
        else
            @chartType = "Bar" if @chartType isnt "Line"
            # when local storage does not specify origin toggle value, or
            # if just changed chart types, then insist first view of bar chart is grounded at 0
            # and make sure that button is toggled down
            if @chartOptions.justChanged is "chartType" or (@chartType is "Bar" and noSpecifiedChartType)
                @chartOptions["originY"] = true
                @optionElements.toggleOriginY.toggleClass("active", true)
        @chartOptions.justChanged = ""
        
        $axisControl = @typeSelection.closest("#chart-type")
        $axisControl.find(".chart-name").text(" " + @chartType)

        # clear title
        @optionElements.chartTitle?.text("")
        # TODO: this won't be necessary for now...
        # check if there is more than 1 unit for Y-axis, and discard any variables that violates it
        @varsYbyUnit = _.groupBy @varsY, (col) => col.unit
        if (_.size @varsYbyUnit) > 1
            @varsYbyUnit = {}
            for ax,ord in @varsY
                u = ax.unit
                (@varsYbyUnit[u] ?= []).push ax
            @varsY = @varsY.filter (v) => v?
        # TODO validation of each axis type with the chart type
        # find out remaining variables: all the axis candidates that haven't been used as in @shelves yet
        remainingVariables = (
                # if @shelves.length < 3 or (_.size @varsYbyUnit) < 2
                if @shelves[0]? and @shelves[1].length > 0 # filter variables in a third unit when there're already two axes
                    ax for ax in axisCandidates when @varsYbyUnit[ax.unit]? or utils.isNominal ax.type
                else
                    axisCandidates
            ).filter((col) => col.name not in @shelves)

        @typeSelection
            .find("li.chart-type-li").remove().end()
            .append(@constructor.CHART_PICK_CONTROL_SKELETON.render(
                names: chartTypes
            ))
        
        if redrawProjectiles then @renderTargetsAndProjectiles axisCandidates, remainingVariables
        do @display

    renderTargetsAndProjectiles: (axisCandidates, remainingVariables, redrawProjectiles) =>
        # need to show this container to read DOM object dimensions
        @optionElements.chartOptionsContainer.show()

        # add in projectile options and make them draggable
        for v in axisCandidates #remainingVariables
            v.isRatio = utils.isRatio v.type
        # if @optionElements.chartOptionsContainer.find("div.projectile").length is 0
        #     @optionElements.chartOptionsContainer
        #         .find("#chart-options-projectiles")
        #         .append(@constructor.PROJECTILE_OPTION.render(
        #             variables: axisCandidates #remainingVariables
        #         )) if axisCandidates.length > 0 #remainingVariables.length > 0
        @optionElements.chartOptionsContainer.find("#chart-options-projectiles").children().remove()
        @optionElements.chartOptionsContainer.find("#chart-options-projectiles")
            .append(@constructor.PROJECTILE_OPTION.render(
                variables: axisCandidates #remainingVariables
            )) if axisCandidates.length > 0 #remainingVariables.length > 0


        $(".projectile").draggable({
            start: (e) => 
                projectile = $(e.target)
                projectile.css("z-index", 11) # always want currently-dragging projectile to appear in front of other projectiles
                for shelfKey, shelf of @shelves
                    shelf.expand projectile

            stop: (e) =>
                projectile = $(e.target)

                for shelfKey, shelf of @shelves
                    shelf.contract projectile

                # projectile was just dopped on a dropzone; the droppable's drop event was just called
                if projectile.data("droppedOnDropZone") is true
                    projectile.data("droppedOnDropZone", false)
                else 
                    projectile.css("z-index", 10) # reset z-index
                    projectilesHidden = +@optionElements.chartOptionsContainer.find("#chart-options-background").css("opacity") is 0
                    @resetProjectile projectile, projectilesHidden
        })

        # add in target options based on width of projectiles, and make them droppable
        maxWidth = 50
        for projectile in @optionElements.chartOptionsContainer.find("div.projectile")
            w = $(projectile).width()
            if w > maxWidth then maxWidth = w
        maxWidth += 14 # buffer room
        targetNames = _.map(@constructor.ORD_TO_AXIS_NAME, (x) -> x + "=")

        targetTableData = []
        for name in targetNames
            targetTableData.push(
                name: name
                width: maxWidth
                ord: targetTableData.length
            )

        # if @optionElements.chartOptionsContainer.find("div.dropzone").length is 0
        #     @optionElements.chartOptionsContainer
        #         .find("#chart-options-dropzones")
        #         # .remove()
        #         # .end()
        #         .append(@constructor.TARGET_OPTION.render(
        #             variables: targetTableData
        #         )) if remainingVariables.length > 0

        @optionElements.chartOptionsContainer.find("#chart-options-dropzones").children().remove()
                # .remove()
                # .end()
        @optionElements.chartOptionsContainer.find("#chart-options-dropzones")
                .append(@constructor.TARGET_OPTION.render(
                    variables: targetTableData
                )) if remainingVariables.length > 0

        for shelfKey, shelf of @shelves
            do shelf.wasCreated

        strictAcceptingClasses =
            "Y": "ratioVariable"
            "X": null
            "PIVOT": null
            "SMULT": null

        looseAcceptingClasses =
            "Y": if @varsY? and @varsY.length > 0 then "unit-#{@varsY[0].unit}" else null
            "X": null
            "PIVOT": null
            "SMULT": null

        for shelfKey, shelf of @shelves
            shelf.strictlyAccept strictAcceptingClasses[shelfKey]
            shelf.looselyAccept looseAcceptingClasses[shelfKey]

        $(".dropzone").droppable({
            activeClass: "droppable-would-accept",
            hoverClass: "droppable-hover",
            drop: (e, ui) =>
                target = $(e.target)
                projectile = $(ui.draggable)
                
                @dropOnDropZone target, projectile, false
                do @hideProjectiles # hide first, so any old projectiles will also hide
                do @persist
                do @initializeAxes false
            out: (e, ui) =>
                projectile = $(ui.draggable)
                # removing projectile from a target
                if projectile.hasClass("isOnTarget")
                    projectile.removeClass("isOnTarget")
                    target = $(e.target)
                    ord = +target.attr("data-order")
                    shelf = @shelves[@constructor.ORD_TO_AXIS_SHELF[ord]]
                    shelf.remove projectile
                    shelf.expand projectile
                    do @persist
                    do @initializeAxes false
        })

        # place vars in their correct spots
        if @varX?
            projectile = $("div.projectile[data-name='#{@varX.name}']")
            target = $("div.dropzone").eq(@constructor.X_AXIS_ORDINAL)
            if not projectile.hasClass("isOnTarget")
                @dropOnDropZone target, projectile, true

        if @varsY?
            for v in @varsY
                projectile = $("div.projectile[data-name='#{v.name}']")
                target = $("div.dropzone").eq(@constructor.Y_AXIS_ORDINAL)
                if not projectile.hasClass("isOnTarget")
                    @dropOnDropZone target, projectile, true

        if @varsPivot?
            for v in @varsPivot
                projectile = $("div.projectile[data-name='#{v.name}']")
                target = $("div.dropzone").eq(@constructor.PIVOT_AXIS)
                if not projectile.hasClass("isOnTarget")
                    @dropOnDropZone target, projectile, true

        if @varsSmult?
            for v in @varsSmult
                projectile = $("div.projectile[data-name='#{v.name}']")
                target = $("div.dropzone").eq(@constructor.SMULT_AXIS)
                if not projectile.hasClass("isOnTarget")
                    @dropOnDropZone target, projectile, true

        h = $("#chart-options-projectiles").height()
        $("#chart-options-background").css("height", h)

        if @optionElements.chartOptionsPlainText.css("display") isnt "none"
            @showInteractiveMode false

    showInteractiveMode: (show) =>
        if show
            @optionElements.chartOptionsPlainText.hide()
            @optionElements.chartOptionsContainer.show()
        else
            @optionElements.chartOptionsPlainText.show()
            @optionElements.chartOptionsContainer.hide()
            do @updateChartOptionsPlainText

    updateChartOptionsPlainText: =>
        seriesToColor = if @chart? then @chart.seriesToColor else {}
        @optionElements.chartOptionsPlainText.find("span").remove()
        span = "<span>#{@chartType}: "
        textArray = []

        for shelfKey, index in @constructor.ORD_TO_AXIS_SHELF
            varNames = do @shelves[shelfKey].getNames
            if varNames.length > 0
                for vName, vIndex in varNames
                    if seriesToColor[vName]?
                        varNames[vIndex] = "<span style='color:#{seriesToColor[vName]}'>&#9679; #{vName}</span>"
                textArray.push "#{@constructor.ORD_TO_AXIS_NAME[index]} = #{varNames.join(", ")}"
        @optionElements.chartOptionsPlainText.prepend("#{span} #{textArray.join(", ")} </span>")

    moveContainers: (toMoveIn) =>
        left = if toMoveIn then 0 else -600 # this should match left CSS value for containers
        adj = if toMoveIn then -600 else 600

        containers = @optionElements.chartOptionsContainer.find("#chart-options-background-container, #chart-options-projectile-container")
        if +containers.css("left").replace("px", "") isnt left
            containers.css("left", left)
            onTargets = @optionElements.chartOptionsContainer.find(".projectile.isOnTarget")
            for t in onTargets
                left = +$(t).css("left").replace("px", "")
                $(t).css("left", left + adj)


    showProjectiles: (left, top, height) =>
        moveMe = @optionElements.chartOptionsContainer.find(".chart-options-moveme:not(.isOnTarget)")

        @moveContainers true

        # First, position at correct left position
        moveMe.css( {
            left: left + "px"
            top: (height - 24 + 16) + "px" # shelf is 24 pixels (outerHeight); give 16 pixels buffer
        })

        @optionElements.chartOptionsContainer.find(".projectile").data("shiftY", (height - 24 + 16)) # need to remember this to reset projectile properly

        # Then, animate opacity change if hidden
        if +moveMe.eq(0).css("opacity") is 0
            moveMe.animate({
                opacity: 1.0
            }, {
                duration: @animationTime
                specialEasing: {
                  opacity: "easeOutQuad"
                }
            })

    hideProjectiles: =>
        @showInteractiveMode false

        @optionElements.chartOptionsContainer.find(".chart-options-moveme:not(.isOnTarget)").animate({
                opacity: 0.0
            }, {
                duration: @animationTime
                specialEasing: {
                  opacity: "easeOutQuad"
                }
                complete: =>
                    @moveContainers false
            })

    dropOnDropZone: (target, projectile, isDefaultNotDropped) =>
        ord = +target.attr("data-order")
        shelf = @shelves[@constructor.ORD_TO_AXIS_SHELF[ord]]

        if not isDefaultNotDropped
            namesToRemove = shelf.addName projectile
            if namesToRemove?
                for nameToRemove in namesToRemove
                    oldProjectile = $("div.projectile[data-name='#{nameToRemove}']")
                    @resetProjectile oldProjectile, true

        projectile.css("z-index", 2)
        shelf.add projectile, isDefaultNotDropped, @animationTime
        if ord is @constructor.X_AXIS_ORDINAL then @chartOptions.justChanged = "x-axis"

    resetProjectile: (projectile, shouldHide) =>
            projectile.removeClass("isOnTarget")
            left = +@optionElements.chartOptionsContainer.find("#chart-options-background").css("left").replace("px", "")

            # make disappear and reset left attribute value
            if shouldHide
                projectile.animate({
                    opacity: 0.0
                }, {
                    duration: @animationTime,
                    specialEasing: {
                        opacity: "easeOutQuad"
                    }
                    complete: =>
                        projectile.css({
                            left: left
                            top: "0px"
                        })
                })

            # return to position amongst other projectiles
            else
                shiftY = projectile.data("shiftY")

                projectile.animate({
                        left: left
                        top: "#{shiftY}px"
                    }, {
                    duration: @animationTime,
                    specialEasing: {
                        left: "easeOutQuad"
                        top: "easeOutQuad"
                    }
                })

    render: =>
        # create a visualizable data from the table data and current axes/series configuration
        # but only if there is a valid varX and varsY
        return if not @varX? or not @varsY? or @varsY.length is 0

        @smChartData = new ChartData @table, @varX, @varsY, @varsSmult
        idsBySeries = @smChartData.idsBySeries
        chartData = []
        for seriesName, ids of idsBySeries # if no series, idsBySeries will contain all the indices
            chartData.push(new ChartData @table, @varX, @varsY, @varsPivot, ids, seriesName)
        numCharts = chartData.length

        do @renderTitle

        chartClass =
            # decide the actual Chart class here
            switch @chartType
                when "Scatter"
                    ScatterPlot
                when "Bar"
                    BarChart
                when "Line"
                    LineChart
                else
                    throw new Error "#{@chartType}: unknown chart type"

        # insert a new DIV for each small multiple
        @baseElement.find("div.small-multiple").remove()
        for i in [0..numCharts-1]
            @baseElement.append("<div class='small-multiple' style='float:left'></div>")

        # get grid size of small multiples layout
        [numRows, numColumns] = @getSmallMultiplesDimensions numCharts

        @baseElement.css("top", if numCharts is 1 then 0 else 30)
        properties =
            chartWidth: (window.innerWidth  - @baseElement.offset().left * 2 - 10) / numColumns # -10 for buffer room
            chartHeight: (window.innerHeight - @baseElement.offset().top - 30) / numRows # 30 px is height of fixed x-axis title
            isSmallMultiple: numCharts > 1

        # create and render the chart
        # TODO reuse the created chart?
        @chart = undefined
        for i in [0..numCharts-1]
            @chart = new chartClass @baseElement.find("div.small-multiple").eq(i), chartData[i], @chartOptions, properties,
                @optionElements # TODO don't pass optionElements, but listen to change events from @chartOptions
            do @chart.render

        @updateFixedAxisTitles numCharts, @chart.axes[0].label, @chart.axes[1].label
        do @updateChartOptionsPlainText

    updateFixedAxisTitles: (numCharts, xAxisTitle, yAxisTitle) =>
        # update fixed axis titles
        xAxisTitleDiv = @optionElements.fixedXAxisTitle
        yAxisTitleDiv = @optionElements.fixedYAxisTitle

        xAxisTitleDiv.text(if numCharts is 1 then "" else xAxisTitle)
        xAxisTitleDiv.css("height", if numCharts is 1 then "0px" else "30px") 
        yAxisTitleDiv.text(if numCharts is 1 then "" else yAxisTitle)

        # position fixed axis titles
        xAxisTitleDiv.css(
            "top": window.innerHeight - xAxisTitleDiv.height()
            "opacity": 1
        )
        top = @optionElements.chartTitle.offset().top + @optionElements.chartTitle.outerHeight(true)
        top = top + (window.innerHeight - top) / 2
        left = 30 - yAxisTitleDiv.width() / 2
        yAxisTitleDiv.css(
            "top": top
            "left": left
            "opacity": 1
        )

    getSmallMultiplesDimensions: (numCharts) ->
        numColumns = Math.ceil(Math.sqrt numCharts)
        numRows = Math.ceil(numCharts / numColumns)
        return [numRows, numColumns]


    renderTitle: =>
        # set up title
        @optionElements.chartTitle?.html(
            # TODO move this code to a model class, e.g., ResultsQuery
            """
            <strong>#{@varsY[0]?.name}</strong>
            by <strong>#{@varX?.name}</strong> #{
                if @varsPivot.length > 0
                    "for each #{
                        ("<strong>#{name}</strong>" for {name} in @varsPivot
                        ).join ", "}"
                else ""
            } #{
                # XXX remove these hacks into ResultsSection, InputsView, OutputsView
                {inputs,outputs} = _3X_.ResultsSection
                filters = (
                    for name,values of inputs.menuItemsSelected when values?.length > 0
                        "<strong>#{name}=#{values.join(",")}</strong>"
                ).concat(
                    for name,filter of outputs.menuFilter when filter?
                        "<strong>#{name}#{outputs.constructor.serializeFilter filter}</strong>"
                )
                if filters.length > 0
                    "<br>(#{filters.join(" and ")})"
                else ""
            }
            """
        )

