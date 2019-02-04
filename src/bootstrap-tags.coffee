# Bootstrap Tags
# Max Lahey
# November, 2012

window.Tags ||= {}

jQuery ->
  $.tags = (element, options = {}) ->

    # set options for tags
    for key, value of options
      this[key] = value

    @bootstrapVersion ||= "3"

    # set defaults if no option was set
    @readOnly ||= false
    @suggestOnClick ||= false
    @ajaxSuggestions ||= false
    @allowOnlySuggestedTags ||= false
    @suggestions ||= []
    @restrictTo = (if options.restrictTo? then options.restrictTo.concat @suggestions else false)
    @exclude ||= false
    @displayPopovers = (if options.popovers? then true else options.popoverData?)
    @popoverTrigger ||= 'hover'
    @tagClass ||= 'btn-info'
    @tagSize ||= 'md'
    @promptText ||= 'Enter tags...'
    @defaultPlaceholderText ||= ''
    @maxLength
    @caseInsensitive ||= false
    @readOnlyEmptyMessage ||= 'No tags to display...'
    @maxNumTags ||= -1
    @minTagInputWidth = 0
    @suggestionList = []

    # callbacks
    @beforeAddingTag ||= (tag) ->
    @afterAddingTag ||= (tag) ->
    @beforeDeletingTag ||= (tag) ->
    @afterDeletingTag ||= (tag) ->

    # override-able functions
    @definePopover ||= (tag) -> "associated content for \""+tag+"\""
    @excludes ||= -> false
    @tagRemoved ||= (tag) ->

    # override-able key press functions
    @pressedReturn ||= (e) ->
    @pressedDelete ||= (e) ->
    @pressedDown ||= (e) ->
    @pressedUp ||= (e) ->

    # create escaper
    createEscaper = (map) ->
      escaper = (match) -> map[match]
      source = '(?:' + _.keys(map).join('|') + ')';
      testRegexp = RegExp(source);
      replaceRegexp = RegExp(source, 'g');
      return (string) ->
        string = if (string == null) then '' else '' + string;
        return if testRegexp.test(string) then string.replace(replaceRegexp, escaper) else string;
  
    @escape = createEscaper(
      '&': '&amp;'
      '<': '&lt;'
      '>': '&gt;'
      '"': '&quot;'
      "'": '&#x27;'
      '`': '&#x60;'
    );

    # hang on to so we know who we are
    @$element = $(element)

    # tagsArray is list of tags -> define it based on what may or may not be in the dom element
    if options.tagData?
      @tagsArray = options.tagData
    else
      tagData = $('.tag-data', @$element).html()
      @tagsArray = (if tagData? then tagData.split ',' else [])

    # initialize associated content array
    if options.popoverData
      @popoverArray = options.popoverData
    else
      @popoverArray = []
      @popoverArray.push null for tag in @tagsArray

    # returns list of tags
    @getTags = =>
      @tagsArray

    @getTagsContent = =>
      @popoverArray

    @getTagsWithContent = =>
      combined = []
      for i in [0..@tagsArray.length-1]
        combined.push
          tag: @tagsArray[i]
          content: @popoverArray[i]
      combined

    @getTag = (tag) =>
      index = @tagsArray.indexOf tag
      if index > -1 then @tagsArray[index] else null

    @getTagWithContent = (tag) =>
      index = @tagsArray.indexOf tag
      tag: @tagsArray[index], content: @popoverArray[index]

    @hasTag = (tag) =>
      @tagsArray.indexOf(tag) > -1

    ####################
    # add/remove methods
    ####################

    # removeTagClicked is called when user clicks remove tag anchor (x)
    @removeTagClicked = (e) => #
      if e.currentTarget.tagName == "A"
        @removeTag $("span", e.currentTarget.parentElement).text()
        $(e.currentTarget.parentNode).remove()
      @

    # removeLastTag is called when user presses delete on empty input.
    @removeLastTag = =>
      if @tagsArray.length > 0
        @removeTag @tagsArray[@tagsArray.length-1]
        @enableInput() if @canAddByMaxNum()
      @

    # removeTag removes specified tag.
    # - Helper method for removeTagClicked and removeLast Tag
    # - also an exposed method (can be called from page javascript)
    @removeTag = (tag) => # removes specified tag
      if @tagsArray.indexOf(tag) > -1
        return if @beforeDeletingTag(tag) == false
        @popoverArray.splice(@tagsArray.indexOf(tag),1)
        @tagsArray.splice(@tagsArray.indexOf(tag), 1)
        @renderTags()
        @afterDeletingTag(tag)
        @enableInput() if @canAddByMaxNum()
      @

    @canAddByRestriction = (tag) ->
      (@restrictTo == false or @restrictTo.indexOf(tag) != -1)

    @canAddByExclusion = (tag) ->
      (@exclude == false || @exclude.indexOf(tag) == -1) and !@excludes(tag)

    @canAddByMaxNum = ->
      @maxNumTags == -1 or @tagsArray.length < @maxNumTags

    @normalizeTag = (tag) ->
      String(tag).trim()

    # addTag adds the specified tag
    # - Helper method for keyDownHandler and suggestedClicked
    # - exposed: can be called from page javascript
    @addTag = (tag) =>
      tag = @normalizeTag(tag)
      if @canAddByRestriction(tag) and !@hasTag(tag) and tag.length > 0 and @canAddByExclusion(tag) and @canAddByMaxNum()
        return if @beforeAddingTag(tag) == false
        associatedContent = @definePopover(tag)
        @popoverArray.push associatedContent or null
        @tagsArray.push tag
        @afterAddingTag(tag)
        @renderTags()
        @disableInput() unless @canAddByMaxNum()
      @

    # addTagWithContent adds the specified tag with associated popover content
    # It is an exposed method: can be called from page javascript
    @addTagWithContent = (tag, content) =>
      if @canAddByRestriction(tag) and !@hasTag(tag) and tag.length > 0
        return if @beforeAddingTag(tag) == false
        @tagsArray.push tag
        @popoverArray.push content
        @afterAddingTag(tag)
        @renderTags()
      @

    # renameTag renames the specified tag
    # It is an exposed method: can be called from page javascript
    @renameTag = (name, newName) =>
      @tagsArray[@tagsArray.indexOf name] = newName
      @renderTags()
      @

    # setPopover sets the specified (existing) tag with associated popover content
    # It is an exposed method: can be called from page javascript
    @setPopover = (tag, popoverContent) =>
      @popoverArray[@tagsArray.indexOf tag] = popoverContent
      @renderTags()
      @

    ###########################
    # User Input & Key handlers
    ###########################

    @clickHandler = (e) =>
      @makeSuggestions e, true

    @keyDownHandler = (e) =>
      k = (if e.keyCode? then e.keyCode else e.which)
      switch k
        when 13 # enter (submit tag or selected suggestion)
          e.preventDefault()
          @pressedReturn(e)
          tag = e.target.value
          if @suggestedIndex? && @suggestedIndex != -1
            tag = @suggestionList[@suggestedIndex]
          @addTag tag
          e.target.value = ''
          @renderTags()
          @hideSuggestions()
        when 46, 8 # delete
          @pressedDelete(e)
          if e.target.value == ''
            @removeLastTag()
          if e.target.value.length == 1 # is one (which will be deleted after JS processing)
            @hideSuggestions()
        when 40 # down
          @pressedDown(e)
          if @suggestionList.length is 0 and @input.val() == '' and (@suggestedIndex == -1 || !@suggestedIndex?)
            @makeSuggestions e, true
          numSuggestions = @suggestionList.length
          @suggestedIndex = (if @suggestedIndex < numSuggestions-1 then @suggestedIndex+1 else numSuggestions-1)
          @selectSuggested @suggestedIndex
          @scrollSuggested @suggestedIndex if @suggestedIndex >= 0
        when 38 # up
          @pressedUp(e)
          @suggestedIndex = (if @suggestedIndex > 0 then @suggestedIndex-1 else 0)
          @selectSuggested @suggestedIndex
          @scrollSuggested @suggestedIndex if @suggestedIndex >= 0
        when 9, 27 # tab, escape
          @hideSuggestions()
          @suggestedIndex = -1
        else

    @keyUpHandler = (e) =>
      k = (if e.keyCode? then e.keyCode else e.which)
      if k != 40 and k != 38 and k != 27
        @makeSuggestions e, false

    @getSuggestions = (str, overrideLengthCheck) ->
      @suggestionList = []
      str = str.toLowerCase() if @caseInsensitive
      $.each @suggestions, (i, suggestion) =>
        suggestionVal = if @caseInsensitive then suggestion.substring(0, str.length).toLowerCase() else suggestion.substring(0, str.length)
        if @tagsArray.indexOf(suggestion) < 0 and suggestionVal == str and (str.length > 0 or overrideLengthCheck)
          @suggestionList.push suggestion
      @suggestionList

    # makeSuggestions creates auto suggestions that match the value in the input
    # if overrideLengthCheck is set to true, then if the input value is empty (''), return all possible suggestions
    @makeSuggestions = (e, overrideLengthCheck, val) =>
      val ?= (if e.target.value? then e.target.value else e.target.textContent)
      @suggestedIndex = -1
      @$suggestionList.html ''

      populateSuggestions = (suggestions) =>
        $.each suggestions, (i, suggestion) =>
          @$suggestionList.append @template 'tags_suggestion',
            suggestion: @escape(suggestion)
        @$('.tags-suggestion').mouseover @selectSuggestedMouseOver
        @$('.tags-suggestion').click @suggestedClicked
        if @suggestionList.length > 0
          @showSuggestions()
        else
          @hideSuggestions() # so the rounded parts on top & bottom of dropdown do not show up

      if typeof @ajaxSuggestions == 'function'
        @suggestions = []
        @restrictTo = [] if @allowOnlySuggestedTags is true
        @ajaxSuggestions(val).then (suggestions) =>
          @suggestedIndex = -1
          @$suggestionList.html ''
          @suggestionList = @suggestions = suggestions
          @restrictTo = @suggestionList if @allowOnlySuggestedTags is true
          populateSuggestions @suggestionList
      else
        populateSuggestions @getSuggestions(val, overrideLengthCheck)

    # triggered when user clicked on a suggestion
    @suggestedClicked = (e) =>
      tag = e.target.textContent
      if @suggestedIndex != -1
        tag = @suggestionList[@suggestedIndex]
      @addTag tag
      @input.val ''
      @makeSuggestions e, false, ''
      @input.focus() # return focus to input so user can continue typing
      @hideSuggestions()

    #################
    # display methods
    #################

    # hideSuggestions is called when:
    # - user clicks out of suggestions list
    # - user selects a suggestion
    # - user presses escape
    @hideSuggestions = =>
      @suggestionList = []
      @suggestedIndex = -1
      @$('.tags-suggestion-list').css display: "none"

    # showSuggetions is called when:
    # - user types in start of a suggested tag
    # - user presses down arrow in empty text input
    @showSuggestions = =>
      @$('.tags-suggestion-list').css display: "block"

    # selectSuggestedMouseOver triggered when user mouses over suggestion
    @selectSuggestedMouseOver = (e) =>
      $('.tags-suggestion').removeClass('tags-suggestion-highlighted')
      $(e.target).addClass('tags-suggestion-highlighted')
      $(e.target).mouseout @selectSuggestedMousedOut
      @suggestedIndex = @$('.tags-suggestion').index($(e.target))

    # selectSuggestedMouseOver triggered when user mouses out of suggestion
    @selectSuggestedMousedOut = (e) =>
      $(e.target).removeClass('tags-suggestion-highlighted')

    # selectSuggested is called when up or down arrows are pressed in
    # a suggestions list (to highlight whatever the specified index is)
    @selectSuggested = (i) =>
      $('.tags-suggestion').removeClass('tags-suggestion-highlighted')
      tagElement = @$('.tags-suggestion').eq(i)
      tagElement.addClass 'tags-suggestion-highlighted'

    # scrollSuggested is called from up and down arrow key presses
    # to scroll the suggestions list so that the selected index is always visible
    @scrollSuggested = (i) =>
      tagElement = @$('.tags-suggestion').eq i
      topElement = @$('.tags-suggestion').eq 0
      pos = tagElement.position()
      topPos = topElement.position()
      @$('.tags-suggestion-list').scrollTop pos.top - topPos.top if pos?

    # adjustInputPadding adjusts padding of input so that what the
    # user types shows up next to last tag (or on new line if insufficient space)
    @adjustInputPosition = =>
      tagElement = @$('.tag').last()
      tagPosition = tagElement.position()
      tagListWidth = @$element.width()

      pTop = if tagPosition? then tagPosition.top else 0
      pLeft = 0
      if tagPosition?
        pLeft = tagPosition.left + tagElement.outerWidth(true)
        if (pLeft + @minTagInputWidth) >= tagListWidth
          pLeft = 0
          pTop += tagElement.outerHeight(true)
      pWidth = tagListWidth - pLeft
      pWidth = '100%' if pWidth is 0

      $('.tags-input', @$element).css
        paddingLeft : Math.max pLeft, 0
        paddingTop  : Math.max pTop, 0
        width       : pWidth
      pBottom = if tagPosition? then tagPosition.top + tagElement.outerHeight(true) else 0
      @$element.css paddingBottom : pBottom - @$element.height()

    # renderTags renders tags...
    @renderTags = =>
      tagList = @$('.tags')
      tagList.html('')
      @input.attr 'placeholder', (if @tagsArray.length == 0 then @promptText else @defaultPlaceholderText)
      @input.attr 'maxlength', @maxLength if @maxLength
      $.each @tagsArray, (i, tag) =>
        tag = $(@formatTag i, tag)
        $('a', tag).click @removeTagClicked
        $('a', tag).mouseover @toggleCloseColor
        $('a', tag).mouseout @toggleCloseColor
        @initializePopoverFor(tag, @tagsArray[i], @popoverArray[i]) if @displayPopovers
        tagList.append tag
      @adjustInputPosition()
      setTimeout =>
        @adjustInputPosition()
      , 200

    @renderReadOnly = =>
      tagList = @$('.tags')
      tagList.html (if @tagsArray.length == 0 then @readOnlyEmptyMessage else '')
      $.each @tagsArray, (i, tag) =>
        tag = $(@formatTag i, tag, true)
        @initializePopoverFor(tag, @tagsArray[i], @popoverArray[i]) if @displayPopovers
        tagList.append tag


    @disableInput = ->
      @$('input').prop 'disabled', true

    @enableInput = ->
      @$('input').prop 'disabled', false

    # set up popover for a given tag to be toggled by specific action
    # - 'click': need to click a tag to show/hide popover
    # - 'hover': need to mouseover/out to show/hide popover
    # - 'hoverShowClickHide': need to mouseover to show popover, mouseover another to hide others, or click document to hide others
    @initializePopoverFor = (tag, title, content) =>
      options =
        title: title
        content: content
        placement: 'bottom'
      if @popoverTrigger == 'hoverShowClickHide'
        $(tag).mouseover ->
          $(tag).popover('show')
          $('.tag').not(tag).popover('hide')
        $(document).click ->
          $(tag).popover('hide')
      else
        options.trigger = @popoverTrigger
      $(tag).popover options


    # toggles remove button opacity for a tag when moused over or out
    @toggleCloseColor = (e) ->
      tagAnchor = $ e.currentTarget
      opacity = tagAnchor.css('opacity')
      opacity = (if opacity < 0.8 then 1.0 else 0.6)
      tagAnchor.css opacity:opacity

    # formatTag spits out the html for a tag (with or without it's popovers)
    @formatTag = (i, tag, isReadOnly = false) =>
      escapedTag = @escape tag
      @template "tag",
        tag: escapedTag
        tagClass: @tagClass
        isPopover: @displayPopovers
        isReadOnly: isReadOnly
        tagSize: @tagSize

    @addDocumentListeners = =>
      $(document).mouseup (e) =>
        containerClass = 'tags-suggestion-list'
        container = @$('.' + containerClass)
        target = @$(e.target)
        if (container.has(e.target).length == 0) and !target.hasClass(containerClass)
          @hideSuggestions()

    @template = (name, options) ->
      Tags.Templates.Template(@getBootstrapVersion(), name, options)

    @$ = (selector) ->
      $(selector, @$element)

    @getBootstrapVersion = -> Tags.bootstrapVersion or @bootstrapVersion

    @initializeDom = ->
      @$element.append @template("tags_container")

    @init = ->
      # build out tags from specified markup
      @$element.addClass("bootstrap-tags").addClass("bootstrap-#{@getBootstrapVersion()}")
      @initializeDom()
      if @readOnly
        @renderReadOnly()
        # unexpose exposed functions to add & remove functions
        @removeTag = ->
        @removeTagClicked = ->
        @removeLastTag = ->
        @addTag = ->
        @addTagWithContent = ->
        @renameTag = ->
        @setPopover = ->
      else
        @input = $ @template "input",
          tagSize: @tagSize
        if @suggestOnClick
            @input.click @clickHandler
        @input.keydown @keyDownHandler
        @input.keyup @keyUpHandler
        @$element.append @input
        @$suggestionList = $(@template("suggestion_list"))
        @$element.append @$suggestionList

        # Check for minimum input width (e.g. set by min-width)
        @minTagInputWidth = Math.max $('.tags-input', @$element).width(1).width()

        # show it
        @renderTags()

        @disableInput() unless @canAddByMaxNum()

        @addDocumentListeners()

    @init()

    @

  # $(selector).tags(index = 0) will return specified index tags object
  # associated with selector or (if none specified), the first
  $.fn.tags = (options) ->
    tagsObject = {}
    stopOn = (if typeof options == "number" then options else -1)
    @each (i, el) ->
      $el = $ el
      unless $el.data('tags')?
        $el.data 'tags', new $.tags(this, options)
      if stopOn == i or i == 0 # return first or specified by index tags object
        tagsObject = $el.data 'tags'
    tagsObject
