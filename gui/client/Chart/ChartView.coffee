$ = require "jquery"
_ = require "underscore"
d3 = require "d3"
require "jsrender"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

CompositeElement = require "CompositeElement"

ChartData = require "ChartData"


class Chart
    constructor: (@baseElement, @data, @chartOptions, @optionElements) ->
        @type = null # TODO REFACTORING instead of branching off with @type, override with subclasses

    render: =>
        do @setupAxes
        do @createSVG
        do @renderXaxis
        do @renderYaxis
        do @renderData

        # TODO REFACTORING change the following code to modify ChartOptions
        # TODO REFACTORING let ChartView listen to ChartOptions' change events and update @optionElements instead
        ## update optional UI elements
        @optionElements.toggleLogScale.toggleClass("disabled", true)
        for axis in @axes
            @optionElements["toggleLogScale#{axis.name}"]
               ?.toggleClass("disabled", not axis.isLogScalePossible)

        @optionElements.toggleOrigin.toggleClass("disabled", true)
        @optionElements["toggleOriginY1"]?.toggleClass("disabled", utils.intervalContains axis.domain, 0)
        if @type is "Scatter"
            @optionElements["toggleOriginX"]?.toggleClass("disabled", utils.intervalContains axis.domain, 0)

        isLineChartDisabled = @type isnt "Line" # TODO REFACTORING use: @ instanceof LineChart
        $(@optionElements.toggleHideLines)
           ?.toggleClass("disabled", isLineChartDisabled)
            .toggleClass("hide", isLineChartDisabled)
        $(@optionElements.toggleInterpolateLines)
           ?.toggleClass("disabled", isLineChartDisabled or @chartOptions.hideLines)
            .toggleClass("hide", isLineChartDisabled or @chartOptions.hideLines)


    setupAxes: => ## Setup Axes
        @axes = []
        # X axis
        @axes.push axisX =
            name: "X"
            unit: @data.varX.unit
            vars: [@data.varX]
            accessor: @data.accessorFor(@data.varX)
        # Y axis: analyze the extent of Y axes data
        vY = @data.varsY[0]
        @axes.push axisY =
            name: "Y"
            unit: vY.unit
            vars: @data.varsY
            isRatio: utils.isRatio vY
        # figure out the extent for the Y axis
        extent = []
        for col in @data.varsY
            extent = d3.extent(extent.concat(d3.extent(@data.entireRowIndexes, @data.accessorFor(col))))
        axisY.domain = extent
    
    @SVG_STYLE_SHEET: """
        <style>
          .axis path,
          .axis line {
            fill: none;
            stroke: #000;
            shape-rendering: crispEdges;
          }

          .dot, .databar {
            opacity: 0.75;
            cursor: pointer;
          }

          .line {
            fill: none;
            stroke-width: 1.5px;
          }
        </style>
        """
    createSVG: => ## Determine the chart dimension and initialize the SVG root as @svg
            chartBody = d3.select(@baseElement[0])
            @baseElement.find("style").remove().end().append(@constructor.SVG_STYLE_SHEET)
            chartWidth  = window.innerWidth  - @baseElement.position().left * 2
            chartHeight = window.innerHeight - @baseElement.position().top - 20
            @baseElement.css
                width:  "#{chartWidth }px"
                height: "#{chartHeight}px"
            @margin =
                top: 20, bottom: 50
                right: 40, left: 40
            # adjust margins while we prepare the Y scales
            for axisY,i in @axes[1..]
                y = axisY.scale = @pickScale(axisY).nice()
                axisY.axis = d3.svg.axis()
                    .scale(axisY.scale)
                    .tickFormat(d3.format(".3s"))
                numDigits = Math.max _.pluck(y.ticks(axisY.axis.ticks()).map(y.tickFormat()), "length")...
                tickWidth = Math.ceil(numDigits * 6.5) #px per digit
                if i == 0
                    @margin.left += tickWidth
                else
                    @margin.right += tickWidth
            @width  = chartWidth  - @margin.left - @margin.right
            @height = chartHeight - @margin.top  - @margin.bottom
            chartBody.select("svg").remove()
            @svg = chartBody.append("svg")
                .attr("width",  chartWidth)
                .attr("height", chartHeight)
              .append("g")
                .attr("transform", "translate(#{@margin.left},#{@margin.top})")


    renderXaxis: => ## Setup and draw X axis
        axisX = @axes[0]
        axisX.domain = @data.entireRowIndexes.map(axisX.accessor)

        switch @type
            when "Bar"
                # set up scale function
                x = axisX.scale = d3.scale.ordinal()
                    .domain(axisX.domain)
                    .rangeRoundBands([0, @width], .5)
                # d is really the index; xData grabs the value for that index
                axisX.coord = (d) -> x(xData(d))
                xData = axisX.accessor
                axisX.barWidth = x.rangeBand() / @data.varsY.length / Object.keys(@data.dataBySeries).length
            when "Line"
                x = axisX.scale = d3.scale.ordinal()
                    .domain(axisX.domain)
                    .rangeRoundBands([0, @width], .1)
                xData = axisX.accessor
                axisX.coord = (d) -> x(xData(d)) + x.rangeBand()/2
            when "Scatter"
                x = axisX.scale = @pickScale(axisX).nice()
                    .range([0, @width])
                xData = axisX.accessor
                axisX.coord = (d) -> x(xData(d))
            else
                error "Unsupported variable type for X axis", axisX.column
        axisX.label = @formatAxisLabel axisX
        axisX.axis = d3.svg.axis()
            .scale(axisX.scale)
            .orient("bottom")
            .ticks(@width / 100)
        if @type isnt "Scatter"
            skipEvery = Math.ceil(x.domain().length / (@width / 55))
            axisX.axis = axisX.axis.tickValues(x.domain().filter((d, ix) => !(ix % skipEvery)))
        if utils.isRatio @data.varX.type
            axisX.axis = axisX.axis.tickFormat(d3.format(".3s"))
        @svg.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0,#{@height})")
            .call(axisX.axis)
          .append("text")
            .attr("x", @width/2)
            .attr("dy", "3em")
            .style("text-anchor", "middle")
            .text(axisX.label)

    renderYaxis: => ## Setup and draw Y axis
        @axisByUnit = {}
        for axisY,i in @axes[1..]
            y = axisY.scale
                .range([@height, 0])
            axisY.label = @formatAxisLabel axisY
            # draw axis
            orientation = if i == 0 then "left" else "right"
            axisY.axis.orient(orientation)
            @svg.append("g")
                .attr("class", "y axis")
                .attr("transform", if orientation isnt "left" then "translate(#{@width},0)")
                .call(axisY.axis)
              .append("text")
                .attr("transform", "translate(#{
                        if orientation is "left" then -@margin.left else @margin.right
                    },#{@height/2}), rotate(-90)")
                .attr("dy", if orientation is "left" then "1em" else "-.3em")
                .style("text-anchor", "middle")
                .text(axisY.label)
            @axisByUnit[axisY.unit] = axisY

    renderData: =>
        # See: https://github.com/mbostock/d3/wiki/Ordinal-Scales#wiki-category10
        #TODO @decideColors
        color = d3.scale.category10()

        ## Finally, draw each varY and series
        series = 0
        axisX = @axes[0]
        xCoord = axisX.coord
        for yVar in @data.varsY
            axisY = @axisByUnit[yVar.unit]
            yData = @data.accessorFor(yVar)
            yCoord = (d) -> axisY.scale(yData(d))

            for seriesLabel,dataForCharting of @data.dataBySeries
                seriesColor = (d) -> color(series)

                # Splits bars if same x-value within a series; that's why it maintains a count and index
                xMap = {}
                for d in dataForCharting
                    xVal = xCoord(d)
                    if xMap[xVal]?
                        xMap[xVal].count++
                    else
                        xMap[xVal] =
                            count: 1
                            index: 0

                switch @type
                    when "Bar"
                        @svg.selectAll(".databar.series-#{series}")
                            .data(dataForCharting)
                          .enter().append("rect")
                            .attr("class", "databar series-#{series}")
                            .attr("width", (d, ix) => axisX.barWidth / xMap[xCoord(d)].count)
                            .attr("x", (d, ix) => 
                                xVal = xCoord(d)
                                xIndex = xMap[xVal].index
                                xMap[xVal].index++
                                xVal + (series * axisX.barWidth) + axisX.barWidth * xIndex / xMap[xVal].count)
                            .attr("y", (d) => yCoord(d))
                            .attr("height", (d) => @height - yCoord(d))
                            .style("fill", seriesColor)
                            # popover
                            .attr("title",        seriesLabel)
                            .attr("data-content", @formatDataPoint yVar)
                            .attr("data-placement", (d) =>
                                if xCoord(d) < @width/2 then "right" else "left"
                            )
                    else
                        @svg.selectAll(".dot.series-#{series}")
                            .data(dataForCharting)
                          .enter().append("circle")
                            .attr("class", "dot series-#{series}")
                            .attr("r", 5)
                            .attr("cx", xCoord)
                            .attr("cy", yCoord)
                            .style("fill", seriesColor)
                            # popover
                            .attr("title",        seriesLabel)
                            .attr("data-content", @formatDataPoint yVar)
                            .attr("data-placement", (d) =>
                                if xCoord(d) < @width/2 then "right" else "left"
                            )

                switch @type
                    when "Line"
                        unless @chartOptions.hideLines
                            line = d3.svg.line().x(xCoord).y(yCoord)
                            line.interpolate("basis") if @chartOptions.interpolateLines
                            @svg.append("path")
                                .datum(dataForCharting)
                                .attr("class", "line")
                                .attr("d", line)
                                .style("stroke", seriesColor)

                if _.size(@data.varsY) > 1
                    if seriesLabel
                        seriesLabel = "#{seriesLabel} (#{yVar.name})"
                    else
                        seriesLabel = yVar.name
                else
                    unless seriesLabel
                        seriesLabel = yVar.name
                if _.size(@data.varsY) == 1 and _.size(@data.dataBySeries) == 1
                    seriesLabel = null

                # legend
                if seriesLabel?
                    i = dataForCharting.length - 1
                    #i = Math.round(Math.random() * i) # TODO find a better way to place labels
                    d = dataForCharting[i]
                    x = xCoord(d)
                    leftHandSide = x < @width/2
                    inTheMiddle = false # @width/4 < x < @width*3/4
                    @svg.append("text")
                        .datum(d)
                        .attr("transform", "translate(#{xCoord(d)},#{yCoord(d)})")
                        .attr("x", if leftHandSide then 5 else -5).attr("dy", "-.5em")
                        .style("text-anchor", if inTheMiddle then "middle" else if leftHandSide then "start" else "end")
                        .style("fill", seriesColor)
                        .text(seriesLabel)

                series++

        # popover
        @baseElement.find(".dot, .databar").popover(
            trigger: "click"
            html: true
            container: @baseElement
        )


    pickScale: (axis) =>
        dom = d3.extent(axis.domain)
        # here is where you ground at 0 if origin selected - by adding it to the extent
        dom = d3.extent(dom.concat([0])) if @chartOptions["origin#{axis.name}"]
        # if the extent min and max are the same, extend each by 1
        if dom[0] == dom[1] or Math.abs (dom[0] - dom[1]) == Number.MIN_VALUE
            dom[0] -= 1
            dom[1] += 1
        axis.isLogScalePossible = not utils.intervalContains dom, 0
        axis.isLogScaleEnabled = @chartOptions["logScale#{axis.name}"]
        if axis.isLogScaleEnabled and not axis.isLogScalePossible
            error "log scale does not work for domains including zero", axis, dom
            axis.isLogScaleEnabled = no
        (
            if axis.isLogScaleEnabled then d3.scale.log()
            else d3.scale.linear()
        ).domain(dom)


    formatAxisLabel: (axis) ->
        unit = axis.unit
        unitStr = if unit then "(#{unit})" else ""
        if axis.vars?.length == 1
            "#{axis.vars[0].name}#{if unitStr then " " else ""}#{unitStr}"
        else
            unitStr

    formatDataPoint: (varY) =>
        vars = @data.relatedVarsFor(varY)
        varAccessors = ([v, @data.accessorFor(v)] for v in vars)
        provenanceFor = @data.provenanceAccessorFor(vars)
        (d) ->
            provenance = provenanceFor(d)
            return "" unless provenance?
            """<table class="table table-condensed">""" + [
                (for [v,vAccessor] in varAccessors
                    val = vAccessor(d)
                    {
                        name: v.name
                        value: """<span class="value" title="#{val}">#{val}</span>#{
                            unless v.unit then ""
                            else "<small class='unit'> (#{v.unit})<small>"}"""
                    }
                )...
                {
                    name: "run#.count"
                    value: """<span class="run-details"
                        data-toggle="popover" data-html="true"
                        title="#{provenance?.length} runs" data-content="
                        <small><ol class='chart-run-details'>#{
                            provenance.map((row) ->
                                # TODO show more variables
                                yValue = row[varY.name]
                                runId = row[_3X_.RUN_COLUMN_NAME]
                                "<li><a href='#{runId}/overview'
                                    target='run-details' title='#{runId}'>#{
                                    # show value of varY for this particular run
                                    row[varY.name]
                                }</a></li>"
                            ).join("")
                        }</ol></small>"><span class="value">#{provenance.length
                            }</span><small class="unit"> (runs)</small></span>"""
                }
                # TODO links to runIds
            ].map((row) -> "<tr><td>#{row.name}</td><th>#{row.value}</th></tr>")
             .join("") + """</table>"""


class BarChart extends Chart
    constructor: (args...) ->
        super args...
        @type = "Bar"

class ScatterPlot extends Chart
    constructor: (args...) ->
        super args...
        @type = "Scatter"

class LineChart extends Chart
    constructor: (args...) ->
        super args...
        @type = "Line"



class ChartView extends CompositeElement
    constructor: (@baseElement, @typeSelection, @axesControl, @table, @optionElements = {}) ->
        super @baseElement

        # use local storage to remember previous axes
        @axisNames = try JSON.parse localStorage["chartAxes"]
        @chartType = try JSON.parse localStorage["chartType"]

        # axis-change are the currently used axis pickers; axis-add is the 1 that lets you add more (and has a ...)
        @axesControl
            .on("click", ".axis-add    .axis-var", @actionHandlerForAxisControl @handleAxisAddition)
            .on("click", ".axis-change .axis-var", @actionHandlerForAxisControl @handleAxisChange)
            .on("click", ".axis-change .axis-remove", @actionHandlerForAxisControl @handleAxisRemoval)

        @typeSelection
            .on("click", ".chart-type-li", @actionHandlerForChartTypeControl @handleChartTypeChange)

        @table.on "changed", @initializeAxes
        @table.on "updated", @display

        # if user resizes window, call display at most once every 100 ms
        $(window).resize(_.throttle @display, 100)

        # hide all popover when not clicked on one
        $('html').on("click", (e) =>
            if $(e.target).closest(".dot, .popover").length == 0
                @baseElement.find(".dot").popover("hide")
            if $(e.target).closest(".databar, .popover").length == 0
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

    @AXIS_NAMES: "X Y1".trim().split(/\s+/)

    persist: =>
        localStorage["chartAxes"] = JSON.stringify @axisNames
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
        do @initializeAxes

    actionHandlerForAxisControl: (action) => (e) =>
        e.preventDefault()
        $this = $(e.target)
        $axisControl = $this.closest(".axis-control")
        ord = +$axisControl.attr("data-order")
        name = $this.closest(".axis-var").attr("data-name")
        action ord, name, $axisControl, $this, e
    handleAxisChange: (ord, name, $axisControl) =>
        $axisControl.find(".axis-name").text(name)
        @axisNames[ord] = name
        if ord == 1 then @chartOptions.justChanged = "axis"
        # TODO proceed only when something actually changes
        do @persist
        do @initializeAxes
    handleAxisAddition: (ord, name, $axisControl) =>
        @axisNames.push name
        do @persist
        do @initializeAxes
    handleAxisRemoval: (ord, name, $axisControl) =>
        @axisNames.splice ord, 1
        do @persist
        do @initializeAxes

    @X_AXIS_ORDINAL: 1 # second variable is X
    @Y_AXIS_ORDINAL: 0 # first variable is Y
    
    # initialize @axes from @axisNames (which is saved in local storage)
    initializeAxes: => 
        if @table.deferredDisplay?
            do @table.render # XXX charting heavily depends on the rendered table, so force rendering
        return unless @table.columnsRendered?.length
        # collect candidate variables for chart axes from ResultsTable
        axisCandidates =
            # only the expanded input variables (usually a condition) or output variables (usually measurement) can be charted
            # below logic will add to the axis candidates any expanded input variable or any rendered measured output variable
            # columns are not rendered if they are unchecked in the left-hand panel
            (col for col in @table.columnsRendered when col.isExpanded or col.isMeasured)
        axisCandidates[ord].unit = null for ax,ord in axisCandidates when not ax.unit? or not ax.unit.length? or ax.unit.length is 0
        nominalVariables =
            (axisCand for axisCand in axisCandidates when utils.isNominal axisCand.type)
        ratioVariables =
            (axisCand for axisCand in axisCandidates when utils.isRatio axisCand.type)
        # check if there are enough variables to construct a two-dimensional chart: if so, add toggle buttons on RHS, if not, show a message
        canDrawChart = (possible) =>
            @baseElement.add(@optionElements.chartOptions).toggleClass("hide", not possible)
            @optionElements.alertChartImpossible?.toggleClass("hide", possible)
        # we need at least 1 ratio variable and 2 variables total
        if ratioVariables.length >= 1 and nominalVariables.length + ratioVariables.length >= 2
            canDrawChart yes
        else
            canDrawChart no
            return
        # validate the variables chosen for axes
        defaultAxes = []
        defaultAxes[@constructor.X_AXIS_ORDINAL] = nominalVariables[0]?.name ? ratioVariables[1]?.name
        defaultAxes[@constructor.Y_AXIS_ORDINAL] = ratioVariables[0]?.name
        if @axisNames?
            # find if all axisNames are valid, don't appear more than once, or make them default
            for name,ord in @axisNames when (@axisNames.indexOf(name) isnt ord or not axisCandidates.some (col) => col.name is name)
                @axisNames[ord] = defaultAxes[ord] ? null
            # discard any null/undefined elements
            @axisNames = @axisNames.filter (name) => name?
        else
            # default axes when axisNames are not in local storage
            @axisNames = defaultAxes
        # collect ResultsTable columns that corresponds to the @axisNames
        @vars = @axisNames.map (name) => @table.columns[name]
        # standardize no-units so that "undefined", "null", and an empty string all have null unit
        # TODO: don't set units to null in 2 different places
        @vars[ord].unit = null for ax,ord in @vars when not ax.unit? or not ax.unit.length? or ax.unit.length is 0
        @varX      = @vars[@constructor.X_AXIS_ORDINAL]
        # pivot variables in an array if there are additional nominal variables
        @varsPivot = (ax for ax,ord in @vars when ord isnt @constructor.X_AXIS_ORDINAL and utils.isNominal ax.type)
        # y-axis variables in an array
        # TODO: there should only be 1 y-axis variable for now
        @varsY     = (ax for ax,ord in @vars when ord isnt @constructor.X_AXIS_ORDINAL and utils.isRatio   ax.type)
        # establish which chart type we're using
        chartTypes = "Line Bar".trim().split(/\s+/)
        noSpecifiedChartType = not @chartType?
        # specify which chart types are allowed
        if utils.isRatio @varX.type
            chartTypes.push "Scatter"
            # Keep it a scatterplot
            @chartType = "Scatter" if noSpecifiedChartType or @chartOptions.justChanged is "axis"
        else
            @chartType = "Bar" if @chartType != "Line"
            # when local storage does not specify origin toggle value, or
            # if just changed chart types, then insist first view of bar chart is grounded at 0
            # and make sure that button is toggled down
            if @chartOptions.justChanged is "chartType" or (@chartType == "Bar" and noSpecifiedChartType)
                @chartOptions["originY1"] = true
                @optionElements.toggleOriginY1.toggleClass("active", true)
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
                # remove Y axis variable if it uses a second unit
                if (_.size @varsYbyUnit) > 1
                    delete @varsYbyUnit[u]
                    @varsY[ord] = null
                    ord2 = @vars.indexOf ax
                    @vars.splice ord2, 1
                    @axisNames.splice ord2, 1
            @varsY = @varsY.filter (v) => v?
        # TODO validation of each axis type with the chart type
        # find out remaining variables: all the axis candidates that haven't been used as in @axisNames yet
        remainingVariables = (
                # if @axisNames.length < 3 or (_.size @varsYbyUnit) < 2
                if @axisNames.length < 2
                    axisCandidates
                else # filter variables in a third unit when there're already two axes
                    ax for ax in axisCandidates when @varsYbyUnit[ax.unit]? or utils.isNominal ax.type
            ).filter((col) => col.name not in @axisNames)
        # render the controls
        @axesControl
            .find(".axis-control").remove().end()
            .append(
                for ax,ord in @vars
                    @constructor.AXIS_PICK_CONTROL_SKELETON.render({
                        ord: ord
                        axis: ax
                        variables: (if ord == @constructor.Y_AXIS_ORDINAL then ratioVariables else if ord == @constructor.X_AXIS_ORDINAL then axisCandidates else remainingVariables)
                                    # the first axis (Y) must always be of ratio type
                            .filter((col) => col not in @vars[0..ord]) # and without the current one
                        isOptional: (ord > 1) # there always has to be at least two axes
                    })
            )
        @axesControl.append(@constructor.AXIS_ADD_CONTROL_SKELETON.render(
            variables: remainingVariables
        )) if remainingVariables.length > 0

        @typeSelection
            .find("li.chart-type-li").remove().end()
            .append(@constructor.CHART_PICK_CONTROL_SKELETON.render(
                names: chartTypes
            ))

        do @display

    render: =>
        # create a visualizable data from the table data and current axes/series configuration
        @chartData = new ChartData @table, @varX, @varsY, @varsPivot

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

        # create and render the chart
        # TODO reuse the created chart?
        @chart = new chartClass @baseElement, @chartData, @chartOptions,
            @optionElements # TODO don't pass optionElements, but listen to change events from @chartOptions
        do @chart.render


    renderTitle: =>
        # set up title
        @optionElements.chartTitle?.html(
            # TODO move this code to a model class, e.g., ResultsQuery
            """
            <strong>#{@varsY[0]?.name}</strong>
            by <strong>#{@varX.name}</strong> #{
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

