"""MediScan AI provider using Groq's OpenAI-compatible API.

Required environment variable: GROQ_API_KEY
Optional: GROQ_MODEL (defaults to qwen/qwen3.8-27b, which supports images and JSON mode).
"""
from __future__ import annotations

import base64
import json
import os
from typing import Any

from groq import Groq

_API_KEY = os.environ.get("GROQ_API_KEY", "").strip()
_MODEL_NAME = os.environ.get("GROQ_MODEL", "qwen/qwen3.8-27b").strip()
_client = Groq(api_key=_API_KEY) if _API_KEY else None

_RESPONSE_SHAPE = """Return a JSON object with exactly these fields:
{
  "identified": true,
  "brand_name": "string",
  "generic_name": "string",
  "category": "one of: Fever & Pain, Allergy, Digestive, Antibiotic, Vitamins, Cold & Flu, Other",
  "purpose": {"en": "1-2 plain sentences", "ur": "same meaning in Urdu script"},
  "dosage": {"en": "safe general guidance, 1-2 sentences", "ur": "same in Urdu"},
  "precaution": {"en": "key warning, 1 sentence", "ur": "same in Urdu"}
}
Use identified=false when the image/name cannot be matched reliably. For an uncertain match, prefix brand_name with "Possibly: ". Never invent a dose, strength, active ingredient, or medical fact. If the exact product or strength cannot be verified, say to check the package and ask a pharmacist. Keep all fields present even when uncertain."""

_IMAGE_SYSTEM = f"""You help identify medicines from photos of packaging, labels, bottles, or blister strips.
Read printed text carefully. Do not identify a pill solely from its color or shape; many medicines look alike. If the label is unreadable or no medicine is visible, return identified=false and ask the user to take a clearer photo or consult a pharmacist.

Safety: do not prescribe, infer an individual dose, or invent ingredients/strength. The result is informational only and must tell users to verify the packaging with a pharmacist when uncertain.

{_RESPONSE_SHAPE}"""

_TEXT_SYSTEM = f"""You identify medicines from a spoken or typed name, often transcribed by phone speech recognition.

The input may be an approximate phonetic spelling rather than the medicine's correct spelling. Be tolerant of pronunciation and transcription variation, including South Asian / Pakistani accents, Urdu-influenced English, vowel changes, dropped or added syllables, similar-sounding consonants, and words split or joined incorrectly. For example, a transcript like "panadole" may mean "Panadol" and "brufin" may mean "Brufen". Treat these as examples of the general problem, not as a closed list of accepted variants.

Before identifying the medicine, mentally generate plausible brand-name candidates that sound like the transcript, then compare them with real, known medicines. Use the full sound pattern, not just a loose spelling resemblance. If one established medicine is a strong match, identify it and use its correct standard spelling. Do not require the user to pronounce or spell a brand perfectly.

SAFETY RULES:
- Do not guess a medicine merely because it is common or because one name looks vaguely similar.
- If two or more real medicines could plausibly match, or the match is weak, set identified=false or prefix brand_name with "Possibly: ". State that the user should confirm the name from the package or with a pharmacist.
- Never infer the product's strength, active ingredient, formulation, or dosage from a brand name alone unless the fact is reliably established. Never invent dosage instructions.
- Do not treat a phonetic match as proof that the medicine itself has been verified. Keep all fields in the required JSON shape.

{_RESPONSE_SHAPE}"""

_CHAT_SYSTEM_TEMPLATE = """You provide brief informational help inside MediScan, a medicine-information app. Answer in {language} using plain language, normally 2-4 sentences. Do not claim to be a doctor. Do not make up facts or provide personalized dosing. For medicine interactions, children, pregnancy, severe symptoms, overdose, or urgent concerns, advise the user to contact a pharmacist/doctor or local emergency service. If medicine context is provided, use it but do not assume it is correctly identified.

Medicine context (may be absent or uncertain):
{medicine_context}"""


class AiQuotaError(Exception):
    """A Groq request was rejected because of a rate/quota limit."""


def _client_or_raise() -> Groq:
    if _client is None:
        raise RuntimeError("GROQ_API_KEY is not configured on the backend.")
    return _client


def _json_from_response(content: str | None) -> dict[str, Any]:
    if not content or not content.strip():
        raise ValueError("The AI provider returned an empty response. Please try again.")
    text = content.strip()
    if text.startswith("```"):
        pieces = text.split("```")
        if len(pieces) >= 2:
            text = pieces[1].strip()
            if text.lower().startswith("json"):
                text = text[4:].strip()
    try:
        result = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError("The AI provider returned invalid JSON. Please try again.") from exc
    if not isinstance(result, dict):
        raise ValueError("The AI provider returned an unexpected response format.")

    # Normalize nested values to the exact structure expected by Flutter.
    result.setdefault("identified", False)
    result.setdefault("brand_name", "Unable to identify")
    result.setdefault("generic_name", "Unknown")
    result.setdefault("category", "Other")
    for field, fallback_en, fallback_ur in (
        ("purpose", "Unable to confirm. Please check the package with a pharmacist.", "تصدیق نہیں ہو سکی۔ براہِ کرم فارماسسٹ سے تصدیق کریں۔"),
        ("dosage", "Follow the package label and ask a pharmacist; do not rely on this result for dosing.", "پیکٹ پر درج ہدایات دیکھیں اور فارماسسٹ سے پوچھیں۔ صرف اس جواب کی بنیاد پر خوراک نہ لیں۔"),
        ("precaution", "Verify the medicine and strength with a pharmacist before use.", "استعمال سے پہلے دوا اور اس کی طاقت کی فارماسسٹ سے تصدیق کریں۔"),
    ):
        value = result.get(field)
        if not isinstance(value, dict):
            value = {}
        result[field] = {
            "en": str(value.get("en") or fallback_en),
            "ur": str(value.get("ur") or fallback_ur),
        }
    result["identified"] = bool(result["identified"])
    for field in ("brand_name", "generic_name", "category"):
        result[field] = str(result[field] or "Unknown")
    return result


def _call_groq(messages: list[dict[str, Any]], *, json_mode: bool = False, max_tokens: int = 900) -> str:
    client = _client_or_raise()
    try:
        kwargs: dict[str, Any] = {
            "model": _MODEL_NAME,
            "messages": messages,
            "temperature": 0.2,
            "max_completion_tokens": max_tokens,
        }
        if json_mode:
            kwargs["response_format"] = {"type": "json_object"}
        response = client.chat.completions.create(**kwargs)
        content = response.choices[0].message.content
        if not content:
            raise ValueError("The AI provider returned an empty response. Please try again.")
        return content
    except Exception as exc:  # noqa: BLE001
        status_code = getattr(exc, "status_code", None)
        message = str(exc).lower()
        if status_code == 429 or "rate limit" in message or "quota" in message or "too many requests" in message:
            raise AiQuotaError("Groq's free API limit has been reached. Please wait for the limit to reset and try again.") from exc
        raise


def ai_identify_medicine_from_image(image_bytes: bytes, mime_type: str) -> dict[str, Any]:
    if not image_bytes:
        raise ValueError("The uploaded image is empty.")
    if mime_type not in {"image/jpeg", "image/png", "image/webp"}:
        mime_type = "image/jpeg"
    encoded = base64.b64encode(image_bytes).decode("ascii")
    data_url = f"data:{mime_type};base64,{encoded}"
    content = _call_groq(
        [
            {"role": "system", "content": _IMAGE_SYSTEM},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Identify the medicine shown. Read the printed label if possible. Return only the required JSON object."},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ],
        json_mode=True,
    )
    return _json_from_response(content)


def ai_identify_medicine_from_text(name: str) -> dict[str, Any]:
    clean_name = (name or "").strip()
    if not clean_name:
        raise ValueError("Please provide a medicine name.")
    content = _call_groq(
        [
            {"role": "system", "content": _TEXT_SYSTEM},
            {"role": "user", "content": f'Identify this spoken/typed medicine name: "{clean_name}". Return only the required JSON object.'},
        ],
        json_mode=True,
    )
    return _json_from_response(content)


def ai_chat_reply(message: str, history: list, lang: str, medicine: dict | None) -> str:
    language = "Urdu" if lang == "ur" else "English"
    system = _CHAT_SYSTEM_TEMPLATE.format(
        language=language,
        medicine_context=json.dumps(medicine, ensure_ascii=False) if medicine else "No medicine is currently shown.",
    )
    messages: list[dict[str, Any]] = [{"role": "system", "content": system}]
    for item in (history or [])[-12:]:
        if not isinstance(item, dict):
            continue
        role = "assistant" if item.get("role") == "assistant" else "user"
        text = item.get("text")
        if isinstance(text, str) and text.strip():
            messages.append({"role": role, "content": text[:3000]})
    messages.append({"role": "user", "content": message.strip()[:3000]})
    return _call_groq(messages, max_tokens=500).strip()
