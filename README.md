
# holdable v1.0.0 [![stable](http://badges.github.io/stability-badges/dist/stable.svg)](http://github.com/badges/stability-badges)

A [`Gesture.Responder`](https://github.com/aleclarson/gesture#gestureresponder) for detecting long press gestures on a `View`.

```coffee
hold = Holdable
  minHoldTime: 300    # How long the user must press before a hold is recognized.
  preventDistance: 10 # The maximum distance before a hold is unrecognizable.

hold.didHoldStart (gesture) ->
  # The holding was recognized!

hold.didHoldEnd (gesture) ->
  # The holding ended!

# Mix this into the props of a View!
hold.touchHandlers
```
