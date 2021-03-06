define (require) -> (\

$ = require "jquery"
_ = require "underscore"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

CompositeElement = require "CompositeElement"

class TargetsUI extends CompositeElement
    constructor: (@baseElement) ->
        @currentQueue = null
        @targetKnobs    = $(TargetsUI.TARGET_KNOB_CONTAINER_SKELETON   ).appendTo(@baseElement)
        @targetContents = $(TargetsUI.TARGET_CONTENT_CONTAINER_SKELETON).appendTo(@baseElement)

        super @baseElement

        @targetContents.on "click", ".target .btn", (e) =>
            $btn = $(e.target).closest(".btn")
            $target = $btn.closest(".target")
            target = $target.attr("data-name")
            log "click", target
            for c in $btn.attr("class").split(/\s+/)
                if (m = /^action-(.+)$/.exec c)?
                    action = m[1]
                    @doTargetAction target, action, e, $target

        do @refresh

    doTargetAction: (target, action, e, $target) =>
        log "target action", target, action
        switch action
            when "use"
                $.post("#{_3X_.BASE_URL}/api/run/queue/#{@currentQueue.queue}:target", {
                        target
                    })
            when "edit"
                TODO

    refresh: =>
        # TODO loading feedback
        $.getJSON("#{_3X_.BASE_URL}/api/run/target/")
            .success((@targets) =>
                @currentTarget = _.where(@targets, isCurrent:true)[0]?.target
                do @display
            )

    load: (@currentQueue) =>
        do @display

    @TARGET_KNOB_CONTAINER_SKELETON: """
        <ul class="nav nav-pills"></ul>
        """
    @TARGET_KNOB_SKELETON: $("""
        <script type="text/x-jsrender">
            <li data-name="{{>target}}">
                <a href="#target-{{>target}}" data-toggle="tab">{{>target}}</a>
            </li>
        </script>
        """)

    @TARGET_CONTENT_CONTAINER_SKELETON: """
        <div class="pill-content"></div>
        """
    @TARGET_CONTENT_SKELETON: $("""
        <script type="text/x-jsrender">
            <div id="target-{{>target}}" class="target pill-pane" data-name="{{>target}}">
                <div class="well alert-block">
                    <span class="target-summary"></span>
                    <div class="actions">
                        <div class="pull-left">
                        <!-- TODO
                            <button class="action-edit btn btn-small"
                                title="Edit current target configuration"><i class="icon icon-edit"></i></button>
                        -->
                        </div>
                        <button class="action-use btn btn-small btn-primary"
                            title="Use this target for executing runs in current queue"><i class="icon icon-ok"></i></button>
                    </div>
                </div>
            </div>  
        </script>
        """)

    render: =>
        for name in _.keys(@targets).sort()
            target = @targets[name]
            targetUI = @targetContents.find("#target-#{name}")
            unless targetUI.length > 0
                ctx = {
                    BASE_URL: _3X_.BASE_URL
                }
                $(TargetsUI.TARGET_KNOB_SKELETON.render target, ctx).appendTo(@targetKnobs)
                $target = $(TargetsUI.TARGET_CONTENT_SKELETON.render target, ctx).appendTo(@targetContents)
                do ($target) =>
                    $.getJSON("#{_3X_.BASE_URL}/api/run/target/#{name}")
                    .success((targetInfo) =>
                        _.extend(target, targetInfo)
                        $target.find(".target-summary").html(
                            utils.markdown targetInfo.description?.join("\n")
                        )
                    )
        # adjust UI for current target
        if @currentQueue?
            @targetKnobs.find("li").removeClass("current")
                .filter("[data-name='#{@currentQueue?.target}']").addClass("current")
            @targetContents.find(".action-use").prop(disabled: false)
            @targetContents.find(".target[data-name='#{@currentQueue?.target}']").find(".action-use").prop(disabled: true)
        # show current target tab if none active
        if true or @targetContents.find(".pill-pane.active").length == 0
            t = @targetKnobs?.find("li.current a")
            t = @targetKnobs?.find("li a:first") unless t?.length > 0
            t?.tab("show")

)
