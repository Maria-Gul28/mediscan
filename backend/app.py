"""MediScan Flask API backed by Groq; routes are compatible with the Flutter app."""
import base64
import binascii
import os

from flask import Flask, Response, jsonify, request
from flask_cors import CORS

from ai import AiQuotaError, ai_chat_reply, ai_identify_medicine_from_image, ai_identify_medicine_from_text
from tts import synthesize

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 12 * 1024 * 1024  # image request cap
CORS(app)


@app.errorhandler(413)
def too_large(_error):
    return jsonify({"error": "Image is too large. Please choose a smaller photo."}), 413


@app.get("/api/health")
def health():
    return jsonify({"status": "ok", "provider": "groq"})


@app.post("/api/medicines/identify")
def identify_medicine():
    data = request.get_json(silent=True) or {}
    image_b64 = data.get("image_base64")
    mime_type = data.get("mime_type", "image/jpeg")
    if not isinstance(image_b64, str) or not image_b64.strip():
        return jsonify({"error": "Missing image_base64 in request body."}), 400
    try:
        image_bytes = base64.b64decode(image_b64, validate=True)
    except (binascii.Error, ValueError):
        return jsonify({"error": "Invalid base64 image data."}), 400
    try:
        return jsonify(ai_identify_medicine_from_image(image_bytes, mime_type))
    except AiQuotaError as exc:
        return jsonify({"error": str(exc)}), 429
    except Exception:
        app.logger.exception("Medicine image identification failed")
        return jsonify({"error": "Medicine identification failed. Check backend logs and try again."}), 502


@app.post("/api/medicines/identify-by-name")
def identify_medicine_by_name():
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    name = name.strip() if isinstance(name, str) else ""
    if not name:
        return jsonify({"error": "Missing medicine name."}), 400
    try:
        return jsonify(ai_identify_medicine_from_text(name))
    except AiQuotaError as exc:
        return jsonify({"error": str(exc)}), 429
    except Exception:
        app.logger.exception("Medicine name identification failed")
        return jsonify({"error": "Medicine identification failed. Check backend logs and try again."}), 502


@app.post("/api/chat")
def chat():
    data = request.get_json(silent=True) or {}
    message = data.get("message")
    message = message.strip() if isinstance(message, str) else ""
    if not message:
        return jsonify({"error": "Missing message."}), 400
    try:
        reply = ai_chat_reply(
            message=message,
            history=data.get("history", []),
            lang=data.get("lang", "en"),
            medicine=data.get("medicine"),
        )
        return jsonify({"reply": reply})
    except AiQuotaError as exc:
        return jsonify({"error": str(exc)}), 429
    except Exception:
        app.logger.exception("Chat request failed")
        return jsonify({"error": "Chat failed. Check backend logs and try again."}), 502


@app.post("/api/tts")
def tts():
    data = request.get_json(silent=True) or {}
    text = data.get("text")
    text = text.strip() if isinstance(text, str) else ""
    lang = data.get("lang", "en")
    if not text:
        return jsonify({"error": "Missing text."}), 400
    try:
        return Response(synthesize(text[:1500], lang), mimetype="audio/mpeg")
    except Exception:
        app.logger.exception("Text-to-speech failed")
        return jsonify({"error": "Text-to-speech failed."}), 502


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
