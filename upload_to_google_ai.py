import google.generativeai as genai
import pathlib
import argparse
import os

# Try to get the API key from an environment variable for better security
# User should set GOOGLE_API_KEY in their environment
# Example: export GOOGLE_API_KEY="YOUR_API_KEY" (Linux/macOS)
#          set GOOGLE_API_KEY=YOUR_API_KEY (Windows CMD)
#          $Env:GOOGLE_API_KEY="YOUR_API_KEY" (Windows PowerShell)
API_KEY = os.getenv("GOOGLE_API_KEY")

def upload_file_to_gemini(file_path_str: str, display_name: str = None):
    """
    Uploads a file to Google Generative AI and prints its URI.

    Args:
        file_path_str: Path to the file to upload.
        display_name: Optional display name for the file in Google AI Studio.
    """
    if not API_KEY:
        print("Error: GOOGLE_API_KEY environment variable not set.")
        print("Please set your API key in the GOOGLE_API_KEY environment variable.")
        return

    try:
        genai.configure(api_key=API_KEY)
    except Exception as e:
        print(f"Error configuring Google Generative AI: {e}")
        return

    file_path = pathlib.Path(file_path_str)
    if not file_path.exists():
        print(f"Error: File not found at '{file_path_str}'")
        return

    if not display_name:
        display_name = file_path.name

    print(f"Uploading '{file_path.name}' as display name '{display_name}'...")
    
    try:
        uploaded_file = genai.upload_file(path=file_path, display_name=display_name)
        print(f"Successfully uploaded file!")
        print(f"  Display Name: {uploaded_file.display_name}")
        print(f"  URI: {uploaded_file.uri}")
        print(f"  Name (for deletion): {uploaded_file.name}")
        print("\nUse this URI with your application or TTS Mod.")
        print("Remember, you can delete the file later using its 'Name' if it's no longer needed via genai.delete_file(name=FILE_NAME).")
    except Exception as e:
        print(f"An error occurred during file upload: {e}")
        if hasattr(e, 'message') and "API key not valid" in e.message:
             print("Please ensure your GOOGLE_API_KEY is correct and has the 'Generative Language API' enabled in Google Cloud Console.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Upload a file to Google Generative AI File API.")
    parser.add_argument("file_path", help="The path to the file you want to upload.")
    parser.add_argument("--name", help="Optional display name for the file on Google AI.", default=None)
    
    args = parser.parse_args()
    
    upload_file_to_gemini(args.file_path, args.name)

# Example usage from your terminal:
# python upload_to_google_ai.py "path/to/your/document.pdf" --name "My Awesome PDF Rules"
# python upload_to_google_ai.py "my_rules.txt" 