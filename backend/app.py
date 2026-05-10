from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from services.transcriber import transcribe_audio
from services.parser import parse_expense

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = "uploads"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route("/transcribe", methods=["POST"])
def transcribe():

    if "audio" not in request.files:
        return jsonify({
            "error": "No audio uploaded"
        }), 400

    audio = request.files["audio"]

    file_path = os.path.join(
        UPLOAD_FOLDER,
        audio.filename
    )

    audio.save(file_path)

    try:

        # STEP 1 → Speech to text
        text = transcribe_audio(file_path)

        print("TRANSCRIBED:", text)

        # STEP 2 → AI parsing
        print("\n====================")
        print("TRANSCRIBED TEXT:")
        print(text)
        print("====================\n")
        parsed_data = parse_expense(text)

        print("PARSED:", parsed_data)

        return jsonify(parsed_data)

    except Exception as e:

        return jsonify({
            "error": str(e)
        }), 500


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )