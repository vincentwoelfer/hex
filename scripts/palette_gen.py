import random

from PIL import Image, ImageDraw, ImageFilter


def sanitize_palette(palette: list[str]) -> list[str]:
    if len(palette) < 2:
        raise ValueError("Color palette must contain at least 2 colors.")

    for i, color in enumerate(palette):
        if not color.startswith("#"):
            palette[i] = "#" + color
    return palette


def generate_palette_image(
    palette: list[str],
    output_file: str = "ground_palette.png",
) -> None:
    width: int = 2048
    height: int = 2048
    palette = sanitize_palette(palette)

    # Create a seamless tiling base
    image = Image.new("RGB", (width * 3, height * 3), palette[0])
    draw = ImageDraw.Draw(image)

    # Generate random dots, ensuring some go beyond the edges
    for _ in range(1000):
        color = random.choice(palette)
        radius = random.randint(round(width * 0.03), round(width * 0.10))
        x = random.randint(-radius, width + radius)
        y = random.randint(-radius, height + radius)
        r = [random.uniform(0.4, 1.6) for _ in range(4)]
        # Draw 9 times to create seamless tiling
        for i in range(3):
            for j in range(3):
                draw.ellipse(
                    [
                        x - radius * r[0] + i * width,
                        y - radius * r[1] + j * height,
                        x + radius * r[2] + i * width,
                        y + radius * r[3] + j * height,
                    ],
                    fill=color,
                )

    # Apply strong Gaussian blur
    image = image.filter(ImageFilter.GaussianBlur(30))

    # Extract the center tile
    center_x = width
    center_y = height
    final_image = image.crop((center_x, center_y, center_x + width, center_y + height))

    # Save final image
    final_image.save(output_file)
    print(f"Image saved as {output_file}")

############################################################
#  Palettes
############################################################

# https://coolors.co/673c4f-7f557d-726e97-7698b3-83b5d1
palette_1 = ["#FF5733", "#7f557d", "#726e97", "#7698b3", "#83b5d1"]

# https://coolors.co/c2c2c2-ffcad4-7cb1b6-b9798d-f4937b
palette_2 = ["#c2c2c2", "#ffcad4", "#7cb1b6", "#b9798d", "#f4937b"]

# https://coolors.co/334139-1e2d24-c52184-e574bc-f9b4ed
palette_3 = ["#334139", "#1e2d24", "#c52184", "#47A8BD", "#f9b4ed"]

generate_palette_image(palette_2)
