# Fixing array assignment issue by splitting channels and merging them after

# Create individual channels
r = np.zeros((size, size), dtype=np.uint8)
g = np.zeros((size, size), dtype=np.uint8)
b = np.zeros((size, size), dtype=np.uint8)
a = np.zeros((size, size), dtype=np.uint8)

# White border (opaque)
r[border_mask] = 255
g[border_mask] = 255
b[border_mask] = 255
a[border_mask] = 255

# Inner fade
fade_values = np.zeros_like(a, dtype=np.uint8)
fade_values[inner_mask] = np.clip(fade_alpha, 0, 128).astype(np.uint8)

r[inner_mask] = 255
g[inner_mask] = 255
b[inner_mask] = 255
a[inner_mask] = fade_values[inner_mask]

# Merge channels
image = np.stack([r, g, b, a], axis=-1)
img = Image.fromarray(image, "RGBA")
path = "/mnt/data/centered_fade_circle_1024.png"
img.save(path)

path
