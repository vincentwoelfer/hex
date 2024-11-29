import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import RegularPolygon
import matplotlib.cm as cm
import random
import math

# GLOBALS:

# Hex_tiles
grid = []

# For visualization
# hex_tile_to_cluster_mapping = {}

# clusters_to_hex_tiles_mapping = {}

#########################################################################
def generate_random_color():
    """Generate a random color in RGB format."""
    r = random.random()
    g = random.random()
    b = random.random()
    return (r, g, b)


def generate_hexagonal_grid(radius):
    """Generate a hexagonal grid with axial coordinates."""
    for q in range(-radius, radius + 1):
        for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
            grid.append((q, r))

#########################################################################
"""Map a hex tile (q, r) to its cluster coordinates."""
def map_hex_tile_to_cluster(tile_q, tile_r, cluster_size):
    if cluster_size == 1:
        return (tile_q, tile_r)

    # "matching" operator to modulo - the part thats removed by modulo
    cluster_q = tile_q - (tile_q % cluster_size)
    cluster_r = tile_r - (tile_r % cluster_size)

    return cluster_q, cluster_r

def map_cluster_to_base_tile(cluster_q, cluster_r):
    return (cluster_q, cluster_r)

def map_cluster_to_hex_coordinates(cluster_q, cluster_r, cluster_size):
    """Map cluster coordinates to the top-left hex tile of the cluster and return all coordinates in the cluster."""
    base_q, base_r = map_cluster_to_base_tile(cluster_q, cluster_r)

    # Generate all coordinates in the cluster using the base tile
    # TODO this is wrong
    tiles_in_cluster = []
    for dq in range(0, cluster_size):
        for dr in range(0, cluster_size):
            tile_q = base_q + dq
            tile_r = base_r + dr
            tiles_in_cluster.append((tile_q, tile_r))

    return tiles_in_cluster

    
def plot_hexagonal_clusters():
    """Visualize hexagonal grid and cluster grouping."""
    hex_tile_to_cluster_mapping = {tile: map_hex_tile_to_cluster(tile[0], tile[1], cluster_size) for tile in grid}

    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_aspect('equal')

    # Assign unique colors to each cluster
    cluster_ids = list(set(hex_tile_to_cluster_mapping.values()))
    cluster_colors = {cluster_id: generate_random_color() for i, cluster_id in enumerate(cluster_ids)}

    for hex_tile, cluster_id in hex_tile_to_cluster_mapping.items():
        color = cluster_colors[cluster_id]

        q, r = hex_tile
        x = 3/2 * q  # X coordinate for axial layout
        y = np.sqrt(3) * (r + q / 2)  # Y coordinate for axial layout

        hexagon = RegularPolygon((x, y), numVertices=6, radius=0.95, orientation=np.radians(30),
                                 facecolor=color, edgecolor='black')
        ax.add_patch(hexagon)

    ax.set_xlim(-15, 15)
    ax.set_ylim(-15, 15)
    plt.axis('off')
    plt.show()

# Example usage
if __name__ == "__main__":
    grid_radius = 8  # Radius of the entire grid
    cluster_size = 2  # Configurable cluster size

    # Generate grid
    generate_hexagonal_grid(grid_radius)

    # Assign clusters using offset tiling
    # assign_hexagonal_clusters_offset(cluster_size)

    # Map clusters to hex tiles
    # map_cluster_to_hex_tiles(cluster_mapping)

    # Plot the clusters
    plot_hexagonal_clusters()

    # Example outputs
    # print("Cluster mapping (hex-tile to cluster):")
    # print(list(cluster_mapping.items())[:10])  # Show first 10 mappings

    # print("\nCluster to hex-tiles:")
    # for cluster_id, tiles in list(clusters_to_tiles.items())[:8]:
    #     print(f"Cluster {cluster_id}:\t {tiles}")


    # Test mapping functions
    print("\nMAP hex-tile to cluster:")
    tiles_used = {}
    for (q, r) in grid[:10]:
        cluster_q, cluster_r = map_hex_tile_to_cluster(q, r, cluster_size)
        tiles_used[(q, r)] = (cluster_q, cluster_r)
        print(f"Hex tile ({q:2}, {r:2}) maps to cluster ({cluster_q:2}, {cluster_r:2})")

    print("\nMAP clusters to hex-tile:")
    for (cluster_q, cluster_r) in set(tiles_used.values()):
        base_tile = map_cluster_to_base_tile(cluster_q, cluster_r)
        tiles_in_cluster = map_cluster_to_hex_coordinates(cluster_q, cluster_r, cluster_size)
        print(f"Cluster ({cluster_q:2}, {cluster_r:2}) maps to base_tile ({base_tile[0]:2}, {base_tile[1]:2}) and contains ({len(tiles_in_cluster)}) tiles: {tiles_in_cluster}\n")


    # VERIFY
    print("\nVERIFICATION ERRORS:")    
    for (q, r) in grid:
        # Hex-Tile -> Cluster -> List of tiles in cluster. Verify that original hex tile is this cluster
        cluster_q, cluster_r = map_hex_tile_to_cluster(q, r, cluster_size)
        tiles_in_cluster = map_cluster_to_hex_coordinates(cluster_q, cluster_r, cluster_size)
        assert (q, r) in tiles_in_cluster, f"Hex tile ({q}, {r}) not found in cluster ({cluster_q}, {cluster_r}) which contains {tiles_in_cluster}"


    # Create a dictionary to store tiles for each cluster
    list_of_all_clusters = {map_hex_tile_to_cluster(q, r, cluster_size) for (q, r) in grid}
    cluster_tiles = {}
    for cluster in list_of_all_clusters:
        tiles = map_cluster_to_hex_coordinates(cluster[0], cluster[1], cluster_size)
        assert len(tiles) == cluster_size ** 2, f"Cluster {cluster} does not have {cluster_size ** 2} tiles"
        cluster_tiles[cluster] = set(tiles)

    # Check that tiles in each cluster are not contained in any other cluster
    for cluster, tiles in cluster_tiles.items():
        for other_cluster, other_tiles in cluster_tiles.items():
            if cluster != other_cluster:
                common_tiles = tiles.intersection(other_tiles)
                if common_tiles:
                    print(f"Cluster {cluster} shares tiles with cluster {other_cluster}: {common_tiles}")


