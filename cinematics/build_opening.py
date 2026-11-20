"""Render the replaceable in-game opening using Pillow and FFmpeg."""
from pathlib import Path
from tempfile import TemporaryDirectory
from math import exp, pi, sin
import random
import struct
import subprocess
import wave

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ART = HERE.parent / "art"
SIZE = (1280, 720)
RATE = 22050
SHOTS = [
    ("daon.webp", "다온시  /  2050년 8월 17일", "2050: 마지막 발주",
     "폭우로 도시의 부품 공급망이 끊겼다.", 2.75),
    ("hospital.webp", "다온시 공공병원  /  긴급 무전", "임시 전력 12시간",
     "“지원팀, 들립니까? 여기는 다온시 공공병원. 임시 전력이… ”", 3.75),
    ("hospital.webp", "다온시 공공병원  /  긴급 무전", "신호 소실",
     "", 0.60),
]


def shot(index, asset, kicker, heading, caption):
    image = Image.open(ART / asset).convert("RGBA").resize(SIZE)
    shade = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(shade)
    for y in range(SIZE[1]):
        alpha = 136 if index == 2 else round(194 * max(0, (y - 265) / 455) ** 1.4)
        draw.line((0, y, SIZE[0], y), fill=(6, 14, 22, alpha))
    if index == 2:
        for y in range(112, 659, 8):
            draw.line((0, y, SIZE[0], y), fill=(5, 16, 25, 190))
    image = Image.alpha_composite(image, shade)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, SIZE[0], 46), fill="#060e16")
    draw.rectangle((0, 674, SIZE[0], SIZE[1]), fill="#060e16")
    draw.rectangle((73, 424, 119, 428), fill="#ffca83" if index == 2 else "#84f1d2")
    font = str(ART / "korean.otf")
    draw.text((73, 443), kicker, font=ImageFont.truetype(font, 20), fill="#b6e9df")
    draw.text((70, 470), heading, font=ImageFont.truetype(font, 56), fill="#f2f7f8", stroke_width=1)
    if caption:
        draw.text((73, 561), caption, font=ImageFont.truetype(font, 24), fill="#e0ebeb")
    return image.convert("RGB")


def sound(path):
    duration = sum(row[-1] for row in SHOTS)
    cut = sum(row[-1] for row in SHOTS[:2])
    rng = random.Random(2050)
    frames = bytearray()
    for i in range(round(RATE * duration)):
        t = i / RATE
        bed = (0.065 * sin(2 * pi * 48 * t) + 0.023 * sin(2 * pi * 72 * t))
        bed *= max(0.0, min(1.0, t / 0.35, (cut - t) / 0.16))
        burst = t - cut
        static = 0.17 * rng.uniform(-1, 1) * exp(-23 * burst) if 0 <= burst < 0.23 else 0
        frames.extend(struct.pack("<h", round((bed + static) * 32767)))
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(frames)


def main():
    with TemporaryDirectory(prefix="last-order-intro-") as directory:
        folder = Path(directory)
        timeline = []
        for index, (*content, duration) in enumerate(SHOTS):
            name = f"{index}.png"
            shot(index, *content).save(folder / name)
            timeline.extend([f"file '{name}'", f"duration {duration:.3f}"])
        timeline.append(f"file '{len(SHOTS) - 1}.png'")
        (folder / "sequence.txt").write_text("\n".join(timeline) + "\n")
        sound(folder / "radio.wav")
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "concat", "-safe", "0", "-i", str(folder / "sequence.txt"),
            "-i", str(folder / "radio.wav"), "-map", "0:v:0", "-map", "1:a:0",
            "-vf", "fps=24,format=yuv420p", "-c:v", "libtheora", "-q:v", "6",
            "-c:a", "libvorbis", "-q:a", "4", str(HERE / "opening.ogv"),
        ], check=True)


if __name__ == "__main__":
    main()
