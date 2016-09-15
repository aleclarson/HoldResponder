
# TODO: Support multi-touch holding.

simulateNativeEvent = require "simulateNativeEvent"
emptyFunction = require "emptyFunction"
cloneObject = require "cloneObject"
assertType = require "assertType"
fromArgs = require "fromArgs"
Gesture = require "gesture"
Timer = require "timer"
Type = require "Type"

type = Type "Holdable"

type.inherits Gesture.Responder

type.initArgs (args) ->
  if args[0].shouldCaptureOnMove
    throw Error "'options.shouldCaptureOnMove' is not allowed by Holdable!"
  return

type.defineOptions

  minHoldTime:
    type: Number
    required: yes

  preventDistance:
    type: Number
    default: Infinity

  canHold:
    type: Function
    default: emptyFunction.thatReturnsTrue

type.defineFrozenValues

  _minHoldTime: fromArgs "minHoldTime"

  _preventDistance: fromArgs "preventDistance"

  _canHold: fromArgs "canHold"

type.defineReactiveValues

  _endListener: null

  _captureEvent: null

  _isCapturing: no

  _holdTimer: null

  _isHolding: no

type.initInstance ->

  @_shouldTerminate = =>
    return not @_isHolding

type.defineEvents

  didHoldReject:
    gesture: Gesture.Kind

  didHoldStart:
    gesture: Gesture.Kind

  didHoldEnd:
    gesture: Gesture.Kind

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

    log.it @__id + "._onHoldEnd()"

    if @_isHolding
      @_isHolding = no
      @__events.didHoldEnd @_gesture
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

    if Responder.grantedResponder isnt null
      callback Responder.grantedResponder
      return

    onCapture = Responder.didResponderGrant 1, callback

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

    if this isnt Responder.grantedResponder
      @_simulateTouchMove event

    if this is Responder.grantedResponder
      log.it @__id + ".didHoldStart()"
      @_isHolding = yes
      @_events.didHoldStart @_gesture

    else
      log.it @__id + ".didHoldReject()"
      @__events.didHoldReject @_gesture

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

  __onTouchEnd: (touchCount) ->
    @_onHoldEnd() if touchCount is 0
    @__super arguments

module.exports = type.build()
