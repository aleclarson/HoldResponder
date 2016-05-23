
# TODO: Support multi-touch holding.

{ Responder } = require "gesture"

simulateNativeEvent = require "simulateNativeEvent"
emptyFunction = require "emptyFunction"
assertType = require "assertType"
combine = require "combine"
Timer = require "timer"
Event = require "event"
Type = require "Type"

type = Type "Holdable"

type.inherits Responder

type.createArguments (args) ->
  assert not args[0].shouldCaptureOnMove,
    reason: "'shouldCaptureOnMove' is not supported by Holdable!"
  return args

type.optionTypes =
  minHoldTime: Number
  preventDistance: Number
  canHold: Function

type.optionDefaults =
  preventDistance: Infinity
  canHold: emptyFunction.thatReturnsTrue

type.defineProperties

  isHolding: get: ->
    @_isHolding

type.defineFrozenValues

  didHoldReject: -> Event()

  didHoldStart: -> Event()

  didHoldEnd: -> Event()

  _minHoldTime: (options) -> options.minHoldTime

  _preventDistance: (options) -> options.preventDistance

  _canHold: (options) -> options.canHold

type.defineReactiveValues

  _endListener: null

  _captureEvent: null

  _isCapturing: no

  _holdTimer: null

  _isHolding: no

type.initInstance ->

  @_shouldTerminate = =>
    return not @_isHolding

type.bindMethods [
  "_onHoldStart"
]

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

  _onHoldStart: ->

    @_holdTimer = null

    event = @_captureEvent
    @_captureEvent = null

    if this isnt Responder.capturedResponder
      @_simulateTouchMove event

    if this is Responder.capturedResponder
      log.it @__id + ".didHoldStart()"
      @_isHolding = yes
      @didHoldStart.emit @_gesture

    else
      log.it @__id + ".didHoldReject()"
      @didHoldReject.emit @_gesture

  _onHoldEnd: ->

    log.it @__id + "._onHoldEnd()"

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
  _onResponderCapture: (callback) ->

    if Responder.capturedResponder isnt null
      callback Responder.capturedResponder
      return

    onCapture = Responder.didResponderCapture
      .once callback

    # If no responder captures, stop listening!
    setImmediate -> onCapture.stop()
    return

  # Calls your callback when the given Responder's gesture has ended.
  _onResponderEnd: (responder, callback) ->
    @_endListener.stop() if @_endListener
    @_endListener = responder.didEnd.once (gesture) =>
      @_endListener = null
      callback gesture

  # Calls your callback when the captured Responder's gesture has ended.
  _onCapturedResponderEnd: (callback) ->
    @_onResponderCapture (responder) =>
      return if responder is this
      @_onResponderEnd responder, callback

type.overrideMethods

  __shouldRespondOnStart: ->
    return no unless @__super arguments
    @startTimer()
    return yes

  __shouldCaptureOnStart: (event) ->
    return no unless @_canHold @_gesture
    @startTimer()
    return yes if @__super arguments
    @_captureEvent = combine {}, event.nativeEvent
    @_onCapturedResponderEnd (gesture) =>
      return if @_isCapturing
      @_interrupt gesture.finished
    return no

  __shouldCaptureOnMove: (event) ->
    return yes if @_isCapturing
    return yes if @__super arguments
    @_captureEvent = combine {}, event.nativeEvent
    return no

  __onTouchEnd: (touchCount) ->
    @_onHoldEnd() if touchCount is 0
    @__super arguments

  # __onTouchMove: ->
  #
  #   distance = Math.sqrt (Math.pow @_gesture.dx, 2) + (Math.pow @_gesture.dy, 2)
  #
  #   log.moat 1
  #   log.it @__id + ".onTouchMove()"
  #   log.it "distance = " + distance
  #   log.moat 1
  #
  #   if (not @_isHolding) and (distance >= @_preventDistance)
  #     @terminate()
  #     return
  #
  #   Responder::__onTouchMove.apply this, arguments

module.exports = type.build()
