import sys, soundfile as sf
from kokoro_onnx import Kokoro
model_dir, out_dir, voice, speed = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
k = Kokoro(f"{model_dir}/kokoro-v1.0.onnx", f"{model_dir}/voices-v1.0.bin")
lines = [
  "That fifty-dollar gift card from Grandma...",
  "Where did it go?",
  "Meet Gift Keeper.",
  "All your family's gift cards, in one wallet. With reminders, before they expire.",
  "Stop losing money on forgotten cards.",
  "Send a gift card to anyone, just by text.",
  "Kids can swap cards. Parents say OK.",
  "Start free. Upgrade anytime.",
  "Gift Keeper. Never lose a gift card again.",
]
for i, text in enumerate(lines, 1):
    samples, sr = k.create(text, voice=voice, speed=speed, lang="en-us")
    sf.write(f"{out_dir}/l{i}.wav", samples, sr)
    print(f"l{i} {len(samples)/sr:.2f}s  {text}")
