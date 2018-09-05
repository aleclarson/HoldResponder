
# TODO: Use `ResponderCache.findAncestor` instead of `Responder.current` (which no longer exists)
# TODO: Support multi-touch holding.

{Responder} = require "gesture"

simulateNativeEvent = require "simulateNativeEvent"
emptyFunction = require "emptyFunction"
cloneObject = require "cloneObject"
Timer = require "timer"
Event = require "eve"
Type = require "Type"

type = Type "HoldResponder"

type.inherits Responder

type.defineArgs ->

  required:
    minHoldTime: yes

  types:
    minHoldTime: Number
    preventDistance: Number
    canHold: Function

  defaults:
    preventDistance: Infinity
    canHold: emptyFunction.thatReturnsTrue

type.createArgs (args) ->
  if args[0].shouldCaptureOnMove
    throw Error "'options.shouldCaptureOnMove' is not supported by HoldResponder!"
  return args

type.defineFrozenValues (options) ->

  didHoldReject: Event()

  didHoldStart: Event()

  didHoldEnd: Event()

  _minHoldTime: options.minHoldTime

  _preventDistance: options.preventDistance

  _canHold: options.canHold

type.defineReactiveValues

  _endListener: null

  _captureEvent: null

  _isCapturing: no

  _holdTimer: null

  _isHolding: no

type.defineGetters

  isHolding: -> @_isHolding

  _isPrevented: ->
    gesture = @_gesture
    distance = Math.sqrt Math.pow(gesture.dx, 2) + Math.pow(gesture.dy, 2)
    return distance >= @_preventDistance

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
    return

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
    @_endListener = responder.didRelease.once (gesture) =>
      @_endListener = null
      callback gesture
    return

  # Calls your callback when the tracked Responder's gesture has ended.
  _onGrantedResponderEnd: (callback) ->
    @_onResponderGrant (responder) =>
      if responder isnt this
        @_onResponderEnd responder, callback
      return

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
    return

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
    if @_isHolding or not @_isPrevented
      return @__super arguments
    return @terminate()

  __onTouchEnd: (event) ->
    {touches} = event.nativeEvent
    @_onHoldEnd() if touches.length is 0
    return @__super arguments

  __onTerminationRequest: ->
    return no if @_isHolding
    return @__super arguments

module.exports = type.build()
