import whisper

model = whisper.load_model("medium")

def transcribe_audio(path):

    result = model.transcribe(
    path,
    language="en"
)

    return result["text"]