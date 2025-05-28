import base64
import argparse
import pathlib

def image_to_base64(image_path_str: str):
    """
    Converts an image file to its base64 string representation.

    Args:
        image_path_str: Path to the image file.
    """
    image_path = pathlib.Path(image_path_str)
    if not image_path.is_file():
        print(f"Error: Image file not found at {image_path_str}")
        return

    try:
        with open(image_path, "rb") as image_file:
            encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
        
        print("Base64 encoded string (copy all lines below):")
        print() # Explicit newline

        # Print in chunks to make it easier to copy from some terminals
        chunk_size = 100000 # Adjust chunk size if needed
        for i in range(0, len(encoded_string), chunk_size):
            print(encoded_string[i:i+chunk_size])
        
        print() # Explicit newline
        print(f"Successfully encoded {image_path.name} to Base64.")
        print(f"Total length of Base64 string: {len(encoded_string)}")
    except Exception as e:
        print(f"Error encoding image: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert an image file to a Base64 encoded string.")
    parser.add_argument("image_file", help="The path to the image file (e.g., rules.png)")
    args = parser.parse_args()

    image_to_base64(args.image_file) 