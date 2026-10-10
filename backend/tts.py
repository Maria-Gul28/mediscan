"""Text-to-speech helper for MediScan's /api/tts endpoint.
Uses Edge TTS and falls back to gTTS if Edge TTS is unavailable.
"""
import asyncio
import io

import edge_tts
from gtts import gTTS

_VOICES = {
    "en": "en-US-AriaNeural",
    "ur": "ur-PK-UzmaNeural",
}


async def _edge_audio(text: str, voice: str) -> bytes:
    communicate = edge_tts.Communicate(text, voice)
    output = bytearray()
    async for chunk in communicate.stream():
        if chunk.get("type") == "audio":
            output.extend(chunk["data"])
    if not output:
        raise RuntimeError("Text-to-speech returned no audio.")
    return bytes(output)


def synthesize(text: str, lang: str = "en") -> bytes:
    clean_text = (text or "").strip()[:1500]
    if not clean_text:
        raise ValueError("Text is empty.")
    language = "ur" if lang == "ur" else "en"
    try:
        return asyncio.run(_edge_audio(clean_text, _VOICES[language]))
    except Exception:
        # gTTS fallback; it also returns MP3 bytes.
        output = io.BytesIO()
        gTTS(text=clean_text, lang=language).write_to_fp(output)
        return output.getvalue()
