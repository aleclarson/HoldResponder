
# TODO: Support multi-touch holding.

{Responder} = require "gesture"

simulateNativeEvent = require "simulateNativeEvent"
emptyFunction = require "emptyFunction"
cloneObject = require "cloneObject"
Event = require "Event"
Timer = require "timer"
Type = require "Type"

type = Type "Holdable"

type.inherits Responder

type.defineOptions
  minHoldTime: Number.isRequired
  preventDistance: Number.withDefault Infinity
  canHold: Function.withDefault emptyFunction.thatReturnsTrue

type.initArgs ([ options ]) ->
  if options.shouldCaptureOnMove
    throw Error "'options.shouldCaptureOnMove' is not allowed by Holdable!"

type.defineFrozenValues (options) ->

  didHoldReject: Event {async: no}

  didHoldStart: Event {async: no}

  didHoldEnd: Event {async: no}

  _minHoldTime: options.minHoldTime

  _preventDistance: options.preventDistance

  _canHold: options.canHold

type.defineReactiveValues

  _endListener: null

  _captureEvent: null

  _isCapturing: no

  _holdTimer: null

  _isHolding: no

type.initInstance ->

  @_shouldTerminate = => not @_isHolding

type.defineGetters

  isHolding: -> @_isHolding

type.defineMethods

  startTimer: ->
    return if @_holdTimer
    @_holdTimer = Timer @_minHoldTime, @_onHoldStart
    return

  stopTimer: ->
    return unless @_holdTimer
    @_holdTimer.prevent()
    @_holdTimer = null
    @_captureEvent = null
    return

  _onHoldEnd: ->

    if @_isHolding
      @_isHolding = no
      @didHoldEnd.emit @_gesture
      return

    @stopTimer()

    if @_endListener
      @_endListener.stop()
      @_endListener = null

  _simulateTouchMove: (event) ->

    event.timestamp += 0.001
    for touch in event.changedTouches
      touch.timestamp += 0.001

    @_isCapturing = yes
    simulateNativeEvent event.target, "onTouchMove", event
    @_isCapturing = no

  # Calls your callback with the current (or next) captured Responder.
  _onResponderGrant: (callback) ->

    if Responder.current isnt null
      callback Responder.current
      return

    onCapture = Responder.didGrant 1, callback

    # If no responder captures, stop listening!
    setImmediate -> onCapture.stop()
    return

  # Calls your callback when the given Responder's gesture has ended.
  _onResponderEnd: (responder, callback) ->
    @_endListener.stop() if @_endListener
    @_endListener = responder.didEnd 1, (gesture) =>
      @_endListener = null
      callback gesture

  # Calls your callback when the tracked Responder's gesture has ended.
  _onGrantedResponderEnd: (callback) ->
    @_onResponderGrant (responder) =>
      return if responder is this
      @_onResponderEnd responder, callback

type.defineBoundMethods

  _onHoldStart: ->

    @_holdTimer = null

    event = @_captureEvent
    @_captureEvent = null

    if this isnt Responder.current
      @_simulateTouchMove event

    if this is Responder.current
      @_isHolding = yes
      @didHoldStart.emit @_gesture

    else
      @didHoldReject.emit @_gesture

type.overrideMethods

  __shouldRespondOnStart: ->
    return no unless @__super arguments
    @startTimer()
    return yes

  __shouldCaptureOnStart: (event) ->
    return no unless @_canHold @_gesture
    @startTimer()
    return yes if @__super arguments
    @_captureEvent = cloneObject event.nativeEvent
    @_onGrantedResponderEnd (gesture) =>
      return if @_isCapturing
      @_interrupt gesture.finished
    return no

  __shouldCaptureOnMove: (event) ->
    return yes if @_isCapturing
    return yes if @__super arguments
    @_captureEvent = cloneObject event.nativeEvent
    return no

  __onTouchMove: ->

    distance = Math.sqrt (Math.pow @_gesture.dx, 2) + (Math.pow @_gesture.dy, 2)
    if (not @_isHolding) and (distance >= @_preventDistance)
      @terminate()
      return

    @__super arguments

  __onTouchEnd: (event) ->
    {touches} = event.nativeEvent
    @_onHoldEnd() if touches.length is 0
    @__super arguments

module.exports = type.build()
