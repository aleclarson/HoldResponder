
# TODO: Support multi-touch holding.

{ assertType } = require "type-utils"

{ Responder } = require "gesture"

simulateNativeEvent = require "simulateNativeEvent"
emptyFunction = require "emptyFunction"
combine = require "combine"
Factory = require "factory"
define = require "define"
Timer = require "timer"
Event = require "event"

module.exports = Factory "Holdable",

  kind: Responder

  optionTypes:
    minHoldTime: Number
    preventDistance: Number
    canHold: Function

  optionDefaults:
    preventDistance: Infinity
    canHold: emptyFunction.thatReturnsTrue

  customValues:

    isHolding: get: ->
      @_isHolding

  initArguments: (options) ->
    assert not options.shouldCaptureOnMove?, "'shouldCaptureOnMove' is not supported by Holdable!"
    arguments

  initFrozenValues: (options) ->

    didHoldReject: Event()

    didHoldStart: Event()

    didHoldEnd: Event()

    _minHoldTime: options.minHoldTime

    _preventDistance: options.preventDistance

    _canHold: options.canHold

  initReactiveValues: ->

    _endListener: null

    _captureEvent: null

    _isCapturing: no

    _holdTimer: null

    _isHolding: no

  init: ->

    @_shouldTerminate = =>
      log.it "_shouldTerminate: { isHolding: #{@_isHolding} }"
      return not @_isHolding

  boundMethods: [
    "_onHoldStart"
  ]

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
      @_isHolding = yes
      @didHoldStart.emit @_gesture

    else
      @didHoldReject.emit @_gesture

  _simulateTouchMove: (event) ->

    event.timestamp += 0.001
    for touch in event.changedTouches
      touch.timestamp += 0.001

    @_isCapturing = yes
    simulateNativeEvent event.target, "onTouchMove", event
    @_isCapturing = no

  _onResponderCapture: (callback) ->

    if Responder.capturedResponder isnt null
      callback Responder.capturedResponder
      return

    onCapture = Responder.didResponderCapture
      .once callback

    # If no responder captures, stop listening!
    setImmediate -> onCapture.stop()
    return

  _onResponderEnd: (responder, callback) ->
    @_endListener.stop() if @_endListener
    @_endListener = responder.didEnd.once (gesture) =>
      @_endListener = null
      callback gesture

  _trackCapturedResponder: ->
    @_onResponderCapture (responder) ->
      return if responder is this
      @_onResponderEnd responder, (gesture) ->
        return if @_isCapturing
        @_interrupt gesture.finished

#
# Subclass overrides
#

  __shouldRespondOnStart: ->
    return no unless Responder::__shouldRespondOnStart.apply this, arguments
    @startTimer()
    return yes

  __shouldCaptureOnStart: (event) ->
    return no unless @_canHold @_gesture
    @startTimer()
    return yes if Responder::__shouldCaptureOnStart.apply this, arguments
    @_captureEvent = combine {}, event.nativeEvent
    @_trackCapturedResponder()
    return no

  __shouldCaptureOnMove: (event) ->
    return yes if @_isCapturing
    return yes if Responder::__shouldCaptureOnMove.apply this, arguments
    @_captureEvent = combine {}, event.nativeEvent
    return no

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

  __onTouchEnd: ->

    if @_isHolding
      @_isHolding = no
      @didHoldEnd.emit @_gesture

    else
      @stopTimer()

      if @_endListener
        @_endListener.stop()
        @_endListener = null

    Responder::__onTouchEnd.apply this, arguments
