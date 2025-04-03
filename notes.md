TODO
3D Character Controller:

# https://www.youtube.com/watch?v=C-1AerTEjFU&t=210s

# TODO
- detect stuck enemies

- align trerrain-gen with nav-mesh capabilities
  - improve smooth edges.
    - Take neighbour hex into account?
    - Change inner circle, if dist inner-circle to edge is very small -> sharp edges.
  - Nav-Mesh Generation verbessern? -> use lower-detail version of terrain?
- Thread-Safe materials?

- Avoidance:
  How to use nav-agent but still have own path postprocessing

Mix these two. Write own agent class using NavServer API directly.
https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_navigationagents.html#actor-as-characterbody3d
+ 
https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_agent_avoidance.html

=> Also see
https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_navigationservers.html#server-avoidance-callbacks


=> Use different nav-maps for pathfinding/querrying (depending on size, see below) but use one single map for avoidance-agents so they can all see each other.

# Different Nav-Mesh Maps/Sizes
https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_different_actor_types.html
