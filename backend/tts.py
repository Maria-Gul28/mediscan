
import asyncio
import edge_tts


def synthesize(text: str, lang: str = "en") -> bytes:
    """Generate MP3 speech in English or Urdu."""

    async def generate():
        voice = (
            "ur-PK-UzmaNeural"
            if lang == "ur"
            else "en-US-JennyNeural"
        )

        communicate = edge_tts.Communicate(text, voice)

        audio_chunks = []

        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_chunks.append(chunk["data"])

        return b"".join(audio_chunks)

    return asyncio.run(generate())
