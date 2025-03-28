TODO
3D Character Controller:
# https://www.youtube.com/watch?v=C-1AerTEjFU&t=210s



# TODO
- collision layer -> path smoothing only with rocks, not floor (or enemies ...)
- detect nav-mesh islands -> delete / prevent
- detect stuck enemies
- align trerrain-gen with nav-mesh capabilities
    - improve smooth edges. 1) take neighbour hex into account? 2) change inner circle, if dist inner-circle to edge is very small -> sharp edges.

- Nav-Mesh Generation verbessern?
- Thread-Safe materials?


# Region AABBs:
X-min: -1.875	 X-max: 13.125
X-min: -1.875	 X-max: 13.125
X-min: 13.125	 X-max: 28.125
X-min: -1.875	 X-max: 13.125
X-min: 13.125	 X-max: 28.125
X-min: -1.875	 X-max: 13.125
X-min: 13.125	 X-max: 28.125
X-min: -1.875	 X-max: 13.125
X-min: 13.125	 X-max: 28.125
X-min: 13.125	 X-max: 28.125
X-min: -1.875	 X-max: 13.125
X-min: -1.875	 X-max: 13.125
X-min: 13.125	 X-max: 28.125
X-min: 13.125	 X-max: 28.125
X-min: -1.875	 X-max: 13.125


# VERTS:
min_x: -1.875	 max_x: 13.125
min_x: -1.875	 max_x: 13.125
min_x: -1.875	 max_x: 13.125
min_x: -1.875	 max_x: 13.125
min_x: -1.875	 max_x: 13.125
min_x: -1.875	 max_x: 13.125
X-min: -1.875	 X-max: 13.125
X-min: -1.875	 X-max: 13.125
X-min: -1.875	 X-max: 13.125
X-min: 13.125	 X-max: 28.125
X-min: 13.125	 X-max: 28.125
X-min: 13.125	 X-max: 28.125
X-min: -1.875	 X-max: 13.125
X-min: -1.875	 X-max: 13.125
