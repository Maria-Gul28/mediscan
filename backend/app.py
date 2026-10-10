"""
MediScan backend API - no database version.

Responsibilities:
  1. /api/medicines/identify          - send a photo, get back identified medicine info
  2. /api/medicines/identify-by-name  - send a transcribed voice/typed name, get back
                                          identified medicine info
  3. /api/chat                        - follow-up questions, grounded in whatever
                                          medicine the app currently has on screen
  4. /api/tts                         - text -> MP3 speech (Urdu works on any phone)

Every request is a fresh AI call - there's no local cache or database, by
design.
"""
import os
import base64
from flask import Flask, request, jsonify, Response
from flask_cors import CORS

from ai import (
    ai_identify_medicine_from_image,
    ai_identify_medicine_from_text,
    ai_chat_reply,
    AiQuotaError,
)
from tts import synthesize

app = Flask(__name__)
CORS(app)


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.post("/api/medicines/identify")
def identify_medicine():
    """Body: { "image_base64": "<base64 jpeg/png bytes>", "mime_type": "image/jpeg" }"""
    data = request.get_json(silent=True) or {}
    image_b64 = data.get("image_base64")
    mime_type = data.get("mime_type", "image/jpeg")

    if not image_b64:
        return jsonify({"error": "missing 'image_base64' in body"}), 400

    try:
        image_bytes = base64.b64decode(image_b64)
    except Exception:
        return jsonify({"error": "invalid base64 image data"}), 400

    try:
        result = ai_identify_medicine_from_image(image_bytes, mime_type)
    except AiQuotaError as exc:
        return jsonify({"error": str(exc)}), 429
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": f"identification failed: {exc}"}), 502

    return jsonify(result)


@app.post("/api/medicines/identify-by-name")
def identify_medicine_by_name():
    """
    Body: { "name": "<transcribed medicine name from voice or typed input>" }
    Used by the voice-input flow: speech-to-text happens on-device in the
    Flutter app, the transcribed text is sent here.
    """
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()

    if not name:
        return jsonify({"error": "missing 'name' in body"}), 400

    try:
        result = ai_identify_medicine_from_text(name)
    except AiQuotaError as exc:
        return jsonify({"error": str(exc)}), 429
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": f"identification failed: {exc}"}), 502

    return jsonify(result)


@app.post("/api/chat")
def chat():
    """Body: { "medicine": {...} | null, "history": [...], "message": str, "lang": "en"|"ur" }"""
    data = request.get_json(silent=True) or {}
    message = (data.get("message") or "").strip()
    if not message:
        return jsonify({"error": "missing 'message'"}), 400

    try:
        reply = ai_chat_reply(
            message=message,
            history=data.get("history", []),
            lang=data.get("lang", "en"),
            medicine=data.get("medicine"),
        )
    except AiQuotaError as exc:
        return jsonify({"error": str(exc)}), 429
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": f"chat failed: {exc}"}), 502

    return jsonify({"reply": reply})


@app.post("/api/tts")
def tts():
    """Body: { "text": str, "lang": "en"|"ur" }  ->  audio/mpeg bytes"""
    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    lang = data.get("lang", "en")
    if not text:
        return jsonify({"error": "missing 'text'"}), 400

    try:
        audio = synthesize(text[:1500], lang)
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": f"tts failed: {exc}"}), 502

    return Response(audio, mimetype="audio/mpeg")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=True)