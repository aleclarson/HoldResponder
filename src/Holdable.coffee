
{ Responder } = require "gesture"

Factory = require "factory"
Timer = require "timer"
Event = require "event"

module.exports = Factory "Holdable",

  kind: Responder

  optionTypes:
    minHoldTime: Number
    preventDistance: Number

  optionDefaults:
    preventDistance: Infinity

  customValues:

    isHolding: get: ->
      @_holding

  initFrozenValues: ->

    minHoldTime: options.minHoldTime

    preventDistance: options.preventDistance

    didHoldStart: Event()

    didHoldEnd: Event()

  initReactiveValues: ->

    _holding: no

    _holdTimer: null

  boundMethods: [
    "_onHoldStart"
  ]

  _stopHoldTimer: ->
    return unless @_holdTimer
    @_holdTimer.prevent()
    @_holdTimer = null

  _onHoldStart: ->
    @_holdTimer = null
    @_holding = yes
    @didHoldStart.emit @_gesture

  _onPanResponderGrant: ->
    @_holdTimer = Timer @minHoldTime, @_onHoldStart
    Responder::_onPanResponderGrant.call this

  _onPanResponderMove: ->
    return unless @_gesture
    distance = Math.sqrt (Math.pow @_gesture.dx, 2) + (Math.pow @_gesture.dy, 2)
    return @_onPanResponderTerminate() if distance >= @preventDistance
    Responder::_onPanResponderMove.call this

  _onPanResponderEnd: ->
    if @_holding
      @_holding = no
      @didHoldEnd.emit @_gesture
    Responder::_onPanResponderEnd.call this
