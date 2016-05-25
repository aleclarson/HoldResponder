var Event, Responder, Timer, Type, assertType, combine, emptyFunction, simulateNativeEvent, type;

Responder = require("gesture").Responder;

simulateNativeEvent = require("simulateNativeEvent");

emptyFunction = require("emptyFunction");

assertType = require("assertType");

combine = require("combine");

Timer = require("timer");

Event = require("event");

Type = require("Type");

type = Type("Holdable");

type.inherits(Responder);

type.createArguments(function(args) {
  assert(!args[0].shouldCaptureOnMove, {
    reason: "'shouldCaptureOnMove' is not supported by Holdable!"
  });
  return args;
});

type.optionTypes = {
  minHoldTime: Number,
  preventDistance: Number,
  canHold: Function
};

type.optionDefaults = {
  preventDistance: 2e308,
  canHold: emptyFunction.thatReturnsTrue
};

type.defineProperties({
  isHolding: {
    get: function() {
      return this._isHolding;
    }
  }
});

type.defineFrozenValues({
  didHoldReject: function() {
    return Event();
  },
  didHoldStart: function() {
    return Event();
  },
  didHoldEnd: function() {
    return Event();
  },
  _minHoldTime: function(options) {
    return options.minHoldTime;
  },
  _preventDistance: function(options) {
    return options.preventDistance;
  },
  _canHold: function(options) {
    return options.canHold;
  }
});

type.defineReactiveValues({
  _endListener: null,
  _captureEvent: null,
  _isCapturing: false,
  _holdTimer: null,
  _isHolding: false
});

type.initInstance(function() {
  return this._shouldTerminate = (function(_this) {
    return function() {
      return !_this._isHolding;
    };
  })(this);
});

type.bindMethods(["_onHoldStart"]);

type.defineMethods({
  startTimer: function() {
    if (this._holdTimer) {
      return;
    }
    this._holdTimer = Timer(this._minHoldTime, this._onHoldStart);
  },
  stopTimer: function() {
    if (!this._holdTimer) {
      return;
    }
    this._holdTimer.prevent();
    this._holdTimer = null;
    this._captureEvent = null;
  },
  _onHoldStart: function() {
    var event;
    this._holdTimer = null;
    event = this._captureEvent;
    this._captureEvent = null;
    if (this !== Responder.capturedResponder) {
      this._simulateTouchMove(event);
    }
    if (this === Responder.capturedResponder) {
      log.it(this.__id + ".didHoldStart()");
      this._isHolding = true;
      return this.didHoldStart.emit(this._gesture);
    } else {
      log.it(this.__id + ".didHoldReject()");
      return this.didHoldReject.emit(this._gesture);
    }
  },
  _onHoldEnd: function() {
    log.it(this.__id + "._onHoldEnd()");
    if (this._isHolding) {
      this._isHolding = false;
      this.didHoldEnd.emit(this._gesture);
      return;
    }
    this.stopTimer();
    if (this._endListener) {
      this._endListener.stop();
      return this._endListener = null;
    }
  },
  _simulateTouchMove: function(event) {
    var i, len, ref, touch;
    event.timestamp += 0.001;
    ref = event.changedTouches;
    for (i = 0, len = ref.length; i < len; i++) {
      touch = ref[i];
      touch.timestamp += 0.001;
    }
    this._isCapturing = true;
    simulateNativeEvent(event.target, "onTouchMove", event);
    return this._isCapturing = false;
  },
  _onResponderCapture: function(callback) {
    var onCapture;
    if (Responder.capturedResponder !== null) {
      callback(Responder.capturedResponder);
      return;
    }
    onCapture = Responder.didResponderCapture.once(callback);
    setImmediate(function() {
      return onCapture.stop();
    });
  },
  _onResponderEnd: function(responder, callback) {
    if (this._endListener) {
      this._endListener.stop();
    }
    return this._endListener = responder.didEnd.once((function(_this) {
      return function(gesture) {
        _this._endListener = null;
        return callback(gesture);
      };
    })(this));
  },
  _onCapturedResponderEnd: function(callback) {
    return this._onResponderCapture((function(_this) {
      return function(responder) {
        if (responder === _this) {
          return;
        }
        return _this._onResponderEnd(responder, callback);
      };
    })(this));
  },
  __shouldRespondOnStart: function() {
    if (!this.__super(arguments)) {
      return false;
    }
    this.startTimer();
    return true;
  },
  __shouldCaptureOnStart: function(event) {
    if (!this._canHold(this._gesture)) {
      return false;
    }
    this.startTimer();
    if (this.__super(arguments)) {
      return true;
    }
    this._captureEvent = combine({}, event.nativeEvent);
    this._onCapturedResponderEnd((function(_this) {
      return function(gesture) {
        if (_this._isCapturing) {
          return;
        }
        return _this._interrupt(gesture.finished);
      };
    })(this));
    return false;
  },
  __shouldCaptureOnMove: function(event) {
    if (this._isCapturing) {
      return true;
    }
    if (this.__super(arguments)) {
      return true;
    }
    this._captureEvent = combine({}, event.nativeEvent);
    return false;
  },
  __onTouchEnd: function(touchCount) {
    if (touchCount === 0) {
      this._onHoldEnd();
    }
    return this.__super(arguments);
  }
});

module.exports = type.build();

//# sourceMappingURL=../../map/src/Holdable.map
