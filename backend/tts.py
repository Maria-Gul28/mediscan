"""
Text -> MP3 speech for MediScan.

synthesize(text, lang) returns raw MP3 bytes.

Strategy:
  1. edge-tts (Microsoft neural voices) - best quality, has real Urdu voices.
  2. gTTS (Google Translate TTS) - fallback if edge-tts fails, e.g. because
     the hosting provider's IP is blocked or the service is unreachable.

If both fail, an exception is raised and app.py returns a 502, which makes
the Flutter app fall back to the phone's own voice.
"""
import asyncio
import io

import edge_tts
from gtts import gTTS

_EDGE_VOICES = {
    "ur": "ur-PK-UzmaNeural",
    "en": "en-US-JennyNeural",
}


async def _edge_synthesize(text: str, voice: str) -> bytes:
    communicate = edge_tts.Communicate(text, voice)
    chunks = []
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            chunks.append(chunk["data"])
    audio = b"".join(chunks)
    if not audio:
        raise RuntimeError("edge-tts returned no audio")
    return audio


def _gtts_synthesize(text: str, lang: str) -> bytes:
    buf = io.BytesIO()
    gTTS(text=text, lang="ur" if lang == "ur" else "en").write_fp(buf)
    return buf.getvalue()


def synthesize(text: str, lang: str = "en") -> bytes:
    lang = "ur" if lang == "ur" else "en"
    voice = _EDGE_VOICES[lang]

    try:
        return asyncio.run(_edge_synthesize(text, voice))
    except Exception as edge_err:  # noqa: BLE001
        try:
            return _gtts_synthesize(text, lang)
        except Exception as gtts_err:  # noqa: BLE001
            raise RuntimeError(
                f"edge-tts failed ({edge_err}); gTTS failed ({gtts_err})"
            ) from gtts_err