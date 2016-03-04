var Event, Factory, Responder, Timer;

Responder = require("gesture").Responder;

Factory = require("factory");

Timer = require("timer");

Event = require("event");

module.exports = Factory("Holdable", {
  kind: Responder,
  optionTypes: {
    minHoldTime: Number,
    preventDistance: Number
  },
  optionDefaults: {
    preventDistance: Infinity
  },
  customValues: {
    isHolding: {
      get: function() {
        return this._holding;
      }
    }
  },
  initFrozenValues: function() {
    return {
      minHoldTime: options.minHoldTime,
      preventDistance: options.preventDistance,
      didHoldStart: Event(),
      didHoldEnd: Event()
    };
  },
  initReactiveValues: function() {
    return {
      _holding: false,
      _holdTimer: null
    };
  },
  boundMethods: ["_onHoldStart"],
  _stopHoldTimer: function() {
    if (!this._holdTimer) {
      return;
    }
    this._holdTimer.prevent();
    return this._holdTimer = null;
  },
  _onHoldStart: function() {
    this._holdTimer = null;
    this._holding = true;
    return this.didHoldStart.emit(this._gesture);
  },
  _onPanResponderGrant: function() {
    this._holdTimer = Timer(this.minHoldTime, this._onHoldStart);
    return Responder.prototype._onPanResponderGrant.call(this);
  },
  _onPanResponderMove: function() {
    var distance;
    if (!this._gesture) {
      return;
    }
    distance = Math.sqrt((Math.pow(this._gesture.dx, 2)) + (Math.pow(this._gesture.dy, 2)));
    if (distance >= this.preventDistance) {
      return this._onPanResponderTerminate();
    }
    return Responder.prototype._onPanResponderMove.call(this);
  },
  _onPanResponderEnd: function() {
    if (this._holding) {
      this._holding = false;
      this.didHoldEnd.emit(this._gesture);
    }
    return Responder.prototype._onPanResponderEnd.call(this);
  }
});

//# sourceMappingURL=../../map/src/Holdable.map
