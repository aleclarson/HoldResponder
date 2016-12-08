
# HoldResponder v1.2.0 [![stable](http://badges.github.io/stability-badges/dist/stable.svg)](http://github.com/badges/stability-badges)

A [`Gesture.Responder`](https://github.com/aleclarson/gesture#gestureresponder) for detecting "long press" gestures on a `View`.

### Options

```coffee
# The smallest amount of milliseconds before a hold is recognized.
minHoldTime: Number

# The smallest amount of movement before a hold is not recognizable.
# Defaults to Infinity.
preventDistance: Number

# Must return false if holding should be prevented.
# Defaults to a function that always returns true.
canHold: Function
```

### Properties

```coffee
# Equals true if a recognized hold has not yet ended. (read-only)
hold.isHolding

# An 'Event' that emits when a hold is recognized.
hold.didHoldStart (gesture) ->

# An 'Event' that emits when a recognized hold ends.
hold.didHoldEnd (gesture) ->

# An 'Event' that emits when a hold is prevented by another 'Responder'.
hold.didHoldReject (gesture) ->

# Pass this to a 'View' using 'props.mixin'!
hold.touchHandlers
```

### Prototype

```coffee
# Manually start the timer that recognizes a hold.
hold.startTimer()

# Manually stop the timer from recognizing a hold.
hold.stopTimer()
```
