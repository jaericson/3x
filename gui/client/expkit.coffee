###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

log = (args...) -> console.log args...

Array::joinTextsWithShy = (delim) ->
    ($("<div/>").text(v).html() for v in @).join "&shy;#{delim}"

safeId = (str) -> str.replace(/[#-]/g, "-")


RUN_COLUMN_NAME = "run#"


mapReduce = (map, red) -> (rows) ->
    mapped = {}
    for row in rows
        (mapped[map(row)] ?= []).push row
    reduced = {}
    for key,rowGroup of mapped
        reduced[key] = red(key, rowGroup)

aggregateFunctions =
    count: _.size
    mean: (vs) ->
        if vs.length
            sum = 0; sum += v for v in vs.map parseFloat when not isNaN v
            sum / vs.length
        else
            null
    # TODO more agg fns: median, mode, max, min, ...

enumerateAll = (name) ->
    if ({values} = conditions[name])?
        (vs) -> (v for v in values when v in vs).joinTextsWithShy ","
    else
        (vs) -> vs.joinTextsWithShy ","




conditions = null
conditionsActive = JSON.parse (localStorage.conditionsActive ?= "{}")

persistActiveConditions = ->
    localStorage.conditionsActive = JSON.stringify conditionsActive

updateConditionDisplay = (condUI) ->
    name = condUI.find(".condition-name")?.text()
    values = condUI.find(".condition-value.active").map( -> $(this).text()).get()
    conditionsActive[name] = values
    hasValues = values?.length > 0
    condUI.find(".condition-values")
        ?.html(if hasValues then "=#{values.joinTextsWithShy ","}" else "")
    condUI.toggleClass("active", hasValues)

handleConditionMenuAction = (handle) -> (e) ->
    $this = $(this)
    condUI = $this.closest(".condition")
    ret = handle($this, condUI, e)
    updateConditionDisplay condUI
    persistActiveConditions()
    e.stopPropagation()
    e.preventDefault()
    # TODO skip updateResults if another menu has been open
    $('html').one('click.dropdown.data-api touchstart.dropdown.data-api', e, displayResults)
    ret

initConditions = ->
    displayConditions = (newConditions) ->
        conditions = newConditions
        conditionsUI = $("#conditions")
        skeleton = $("#condition-skeleton")
        for name,{type,values} of conditions
            id = safeId(name)
            # add each variable by filling the skeleton
            conditionsUI.append(skeleton.render({name, id, type, values}))
            condUI = conditionsUI.find("#condition-#{id}")
                .toggleClass("numeric", values.every (v) -> not isNaN parseFloat v)
            # with menu items for each value
            menu = condUI.find(".dropdown-menu")
            isAllActive = do (menu) -> () ->
                menu.find(".condition-value")
                    .toArray().every (a) -> $(a).hasClass("active")
            menu.find(".condition-value")
                .click(do (isAllActive) -> handleConditionMenuAction ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-values-toggle")
                        .toggleClass("active", isAllActive())
                )
                .each ->
                    $this = $(this)
                    value = $this.text()
                    $this.toggleClass("active", value in conditionsActive[name] ? [])
            menu.find(".condition-values-toggle")
                .toggleClass("active", isAllActive())
                .click(handleConditionMenuAction ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-value")
                        .toggleClass("active", $this.hasClass("active"))
                )
            updateConditionDisplay(condUI)
            log "initCondition #{name}:#{type}=#{values.join ","}"

    $.getJSON("/api/conditions")
        .success(displayConditions)




measurementsAggregation = JSON.parse (localStorage.measurementsAggregation ?= "{}")

persistActiveMeasurements = ->
    localStorage.measurementsAggregation = JSON.stringify measurementsAggregation

updateMeasurementDisplay = (measUI) ->
    name = measUI.find(".measurement-name")?.text()
    aggregationActive = measUI.find(".measurement-aggregation.active")
    isActive = aggregationActive.length > 0
    aggregation = if isActive then aggregationActive.first().text() else null
    measurementsAggregation[name] = aggregation
    measUI.find(".dropdown-toggle .measurement-aggregation").text(if isActive then ".#{aggregation}" else "")
    measUI.toggleClass("active", isActive)

handleMeasurementMenuAction = (handle) -> (e) ->
    $this = $(this)
    measUI = $this.closest(".measurement")
    ret = handle($this, measUI, e)
    updateMeasurementDisplay measUI
    persistActiveMeasurements()
    e.preventDefault()
    # TODO skip updateResults if another menu has been open
    $('html').one('click.dropdown.data-api touchstart.dropdown.data-api', e, displayResults)
    ret

initMeasurements = ->
    displayMeasurements = (newMeasurements) ->
        measurements = newMeasurements
        measurementsUI = $("#measurements")
        skeleton = $("#measurement-skeleton")
        # TODO different aggregateFunctions depending on type: string, numbers, ...
        aggNames = ({name: aggName} for aggName of aggregateFunctions)
        for name,{type} of measurements
            id = safeId(name)
            # add each measurement by filling the skeleton
            measurementsUI.append(skeleton.render({name, id, type, aggregateFunctions:aggNames}))
            measUI = measurementsUI.find("#measurement-#{id}")
            # with menu items for aggregateFunctions
            menu = measUI.find(".dropdown-menu")
            menu.find(".measurement-aggregation")
                .click(handleMeasurementMenuAction ($this, measUI) ->
                    # activate or toggle the newly chosen one
                    wasActive = $this.hasClass("active")
                    measUI.find(".dropdown-menu .measurement-aggregation").removeClass("active")
                    $this.toggleClass("active") unless wasActive
                    # Or we could always use at least one
                    # $this.addClass("active")
                )
                .each ->
                    $this = $(this)
                    aggregation = $this.text()
                    $this.toggleClass("active", aggregation == measurementsAggregation[name])
            updateMeasurementDisplay measUI
            log "initMeasurement #{name}:#{type}.#{measurementsAggregation[name]}"

    $.getJSON("/api/measurements")
        .success(displayMeasurements)





emptyResults =
    names: []
    rows: []
updateResults = (e) ->
    if _.values(conditionsActive).some((vs) -> vs?.length > 0)
        $.get("/api/results",
            runs: []
            batches: []
            conditions: JSON.stringify conditionsActive
        ).success(displayNewResults)
    else
        displayNewResults(emptyResults)
    e?.preventDefault?()

results = null
displayNewResults = (newResults) ->
    log "got results:", newResults
    results = newResults
    #$("#results-raw").text(JSON.stringify results, null, 2)
    displayResults()

displayResults = () ->
    # prepare the column ordering
    columnNamesActive   = (name for name of conditions when conditionsActive[name]?.length > 0)
    columnNamesMeasured = (name for name in results.names when not conditions[name])
    columnNames = (name for name of conditions).concat columnNamesMeasured
    columnIndex = {}; idx = 0; columnIndex[name] = idx++ for name in results.names

    # aggregate data
    columnAggregation = {}
    # for measurements, allow choosing different aggregation functions
    for name in columnNamesMeasured
        columnAggregation[name] = aggregateFunctions[measurementsAggregation[name]]
        columnAggregation[name] ?= aggregateFunctions.mean
    columnAggregation[RUN_COLUMN_NAME] ?= aggregateFunctions.count
    for name of conditions
        columnAggregation[name] ?= enumerateAll name
    log "aggregation:", columnAggregation
    groupRowsByColumns = (columns) -> (rows) ->
        map = (row) -> JSON.stringify (row[columnIndex[name]] for name in columns)
        red = (key, rows) ->
            for name in columnNames
                idx = columnIndex[name]
                if name in columns
                    rows[0][idx]
                else
                    values = _.uniq(row[idx] for row in rows)
                    value: (columnAggregation[name] ? enumerateAll name)(values)
                    values: values
        _.values(mapReduce(map, red)(rows))
    aggregatedRows = groupRowsByColumns(columnNamesActive)(results.rows)
    log "aggregated results:", aggregatedRows
    # TODO pad aggregatedRows with missing combination of condition values

    table = $("#results-table")
    # populate table head
    headSkeleton = $("#results-table-head-skeleton")
    thead = table.find("thead")
    thead.find("tr").remove()
    columnMetadata = {}
    thead.append(headSkeleton.render(
        columns: (
            for name in columnNames
                columnMetadata[name] =
                    name: name
                    className: (
                            if name in columnNamesActive then "condition"
                            else if name in columnNamesMeasured then "measurement"
                            else "muted"
                        )
                    isForGrouping: name in columnNamesActive
                    isMeasured: name in columnNamesMeasured
                    isntImportant: conditions[name]? and name not in columnNamesActive
                    isRunIdColumn: name == RUN_COLUMN_NAME
        )
    ))

    # populate table body
    table.find("tbody").remove()
    tbody = $("<tbody>").appendTo(table)
    rowSkeleton = $("#results-table-row-skeleton")
    for row in aggregatedRows
        tbody.append(rowSkeleton.render(
            columns: (
                idx = 0
                for name in columnNames
                    values = null
                    value = row[idx++]
                    if value?.values?.length
                        values = ({name, value:v} for v in value.values)
                        value = value.value
                    $.extend(columnMetadata[name], {values, value})

            )
        ))

    # finally, make the table interactive with DataTable
    table.dataTable(
        bDestroy: true
        bLengthChange: false
        bPaginate: false
        bAutoWidth: false
        sDom: '<"H"fir>t<"F"lp>'
        bStateSave: true
        bProcessing: true
    )





# initialize UI
$ ->
    initConditions()
        .success(initMeasurements)
        .success(updateResults)

