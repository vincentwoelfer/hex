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
    image = Image.new("RGB", (width, height), palette[0])
    draw = ImageDraw.Draw(image)

    # Generate random dots, ensuring some go beyond the edges
    for _ in range(1000):
        color = random.choice(palette)
        radius = random.randint(round(width * 0.03), round(width * 0.12))
        x = random.randint(-radius, width + radius)
        y = random.randint(-radius, height + radius)
        r = [random.uniform(0.4, 1.6) for _ in range(4)]
        draw.ellipse(
            [
                x - radius * r[0],
                y - radius * r[1],
                x + radius * r[2],
                y + radius * r[3],
            ],
            fill=color,
        )

    # Create seamless tiling by mirroring edges
    seamless_image = Image.new("RGB", (width * 2, height * 2))
    seamless_image.paste(image, (0, 0))
    seamless_image.paste(image.transpose(Image.FLIP_LEFT_RIGHT), (width, 0))
    seamless_image.paste(image.transpose(Image.FLIP_TOP_BOTTOM), (0, height))
    seamless_image.paste(image.transpose(Image.ROTATE_180), (width, height))

    # Crop a centered portion to ensure seamless tiling
    crop_x = width // 2
    crop_y = height // 2
    image = seamless_image.crop((crop_x, crop_y, crop_x + width, crop_y + height))

    # Apply strong Gaussian blur
    image = image.filter(ImageFilter.GaussianBlur(30))

    # Save final image
    image.save(output_file)
    print(f"Image saved as {output_file}")


############################################################
#  Palettes
############################################################

# https://coolors.co/673c4f-7f557d-726e97-7698b3-83b5d1
palette_1 = ["#FF5733", "#7f557d", "#726e97", "#7698b3", "#83b5d1"]

# https://coolors.co/ffffff-ffcad4-b0d0d3-c08497-f7af9d
palette_2 = ["#ffffff", "#ffcad4", "#b0d0d3", "#c08497", "#f7af9d"]

# https://coolors.co/334139-1e2d24-c52184-e574bc-f9b4ed
palette_3 = ["#334139", "#1e2d24", "#c52184", "#47A8BD", "#f9b4ed"]

generate_palette_image(palette_3)
