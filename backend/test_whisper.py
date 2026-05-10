import whisper

model = whisper.load_model("medium")

result = model.transcribe("../asset/audio/check4.ogg", language='ta')

print(result["text"])