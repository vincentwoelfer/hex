import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import RegularPolygon
import matplotlib.cm as cm
import random

def generate_random_color():
    """Generate a random color in RGB format."""
    r = random.random()
    g = random.random()
    b = random.random()
    return (r, g, b)


def generate_hexagonal_grid(radius):
    """Generate a hexagonal grid with axial coordinates."""
    grid = []
    for q in range(-radius, radius + 1):
        for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
            grid.append((q, r))
    return grid

def map_hex_tile_to_cluster(q, r, cluster_size):
    """Map a hex tile (q, r) to its cluster coordinates."""
    cluster_q = q // cluster_size
    cluster_r = (r - (q // cluster_size) % 2) // cluster_size
    return cluster_q, cluster_r

def map_cluster_to_hex_coordinates(cluster_q, cluster_r, cluster_size):
    """Map cluster coordinates to the top-left hex tile of the cluster and return all coordinates in the cluster."""
    base_q = cluster_q * cluster_size
    base_r = cluster_r * cluster_size + (cluster_q % 2) * (cluster_size // 2)

    # Generate all coordinates in the cluster
    coordinates = []
    for dq in range(-cluster_size + 1, cluster_size):
        for dr in range(max(-cluster_size + 1, -dq - cluster_size + 1), min(cluster_size, -dq + cluster_size)):
            q = base_q + dq
            r = base_r + dr
            coordinates.append((q, r))

    return base_q, base_r, coordinates

def assign_hexagonal_clusters_offset(grid, cluster_size):
    """Assign clusters using an offset pattern for tiling."""
    cluster_map = {}
    for q, r in grid:
        cluster_map[(q, r)] = map_hex_tile_to_cluster(q, r, cluster_size)
    return cluster_map

def map_cluster_to_hex_tiles(cluster_map):
    """Map clusters to lists of hex tiles."""
    cluster_to_tiles = {}
    for hex_tile, cluster_id in cluster_map.items():
        if cluster_id not in cluster_to_tiles:
            cluster_to_tiles[cluster_id] = []
        cluster_to_tiles[cluster_id].append(hex_tile)
    return cluster_to_tiles

def plot_hexagonal_clusters(grid, cluster_map):
    """Visualize hexagonal grid and cluster grouping."""
    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_aspect('equal')

    # Assign unique colors to each cluster using a colormap
    cluster_ids = list(set(cluster_map.values()))
    cluster_colors = {cluster_id: generate_random_color() for i, cluster_id in enumerate(cluster_ids)}

    for hex_tile, cluster_id in cluster_map.items():
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
    grid_radius = 6  # Radius of the entire grid
    cluster_size = 2  # Configurable cluster size

    # Generate grid
    hex_grid = generate_hexagonal_grid(grid_radius)

    # Assign clusters using offset tiling
    cluster_mapping = assign_hexagonal_clusters_offset(hex_grid, cluster_size)

    # Map clusters to hex tiles
    clusters_to_tiles = map_cluster_to_hex_tiles(cluster_mapping)

    # Plot the clusters
    plot_hexagonal_clusters(hex_grid, cluster_mapping)

    # Example outputs
    print("Cluster mapping (hex-tile to cluster):")
    print(list(cluster_mapping.items())[:10])  # Show first 10 mappings

    print("\nCluster to hex-tiles:")
    for cluster_id, tiles in list(clusters_to_tiles.items())[:5]:  # Show first 5 clusters
        print(f"Cluster {cluster_id}: {tiles}")

    # Test mapping functions
    print("\nTesting coordinate mappings:")
    for i in range(2):
        test_q, test_r = 4, 4+i
        cluster_q, cluster_r = map_hex_tile_to_cluster(test_q, test_r, cluster_size)
        print(f"Hex tile ({test_q}, {test_r}) maps to cluster ({cluster_q}, {cluster_r})")

    base_q, base_r, cluster_coords = map_cluster_to_hex_coordinates(cluster_q, cluster_r, cluster_size)
    print(f"Cluster ({cluster_q}, {cluster_r}) maps to top-left hex tile ({base_q}, {base_r})")
    print(f"All coordinates in this cluster: {cluster_coords}")



