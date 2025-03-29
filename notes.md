TODO
3D Character Controller:

# https://www.youtube.com/watch?v=C-1AerTEjFU&t=210s

# TODO

- collision layer -> path smoothing only with rocks, not floor (or enemies ...)
- detect nav-mesh islands -> delete / prevent
- detect stuck enemies

- align trerrain-gen with nav-mesh capabilities

  - improve smooth edges. 1) take neighbour hex into account? 2) change inner circle, if dist inner-circle to edge is very small -> sharp edges.

- Nav-Mesh Generation verbessern? -> use lower-detail version of terrain?
- Thread-Safe materials?

- Avoidance:
  How to use nav-agent but still have own path postprocessing
  https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html
