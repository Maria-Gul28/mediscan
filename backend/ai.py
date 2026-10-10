"""
Thin wrapper around the Google Gemini API for MediScan's AI features:
  - ai_identify_medicine_from_image: identifies a medicine directly from a
    photo - reads printed text when legible, falls back to visual
    characteristics (pack color, shape, blister pattern) when it isn't.
  - ai_identify_medicine_from_text: identifies a medicine from a spoken/typed
    name (used for the voice-input flow - speech-to-text happens on-device,
    the transcribed name is sent here).
  - ai_chat_reply: the "Ask" follow-up chat, grounded in whatever medicine is
    currently on screen (passed in directly from the app - no database).

Requires GEMINI_API_KEY in the environment. Get a free key (no card required)
at https://aistudio.google.com/apikey

Note: none of this is exposed to the end user as "AI" anywhere in the app's
UI text - the prompts below are written so the underlying model never refers
to itself as an AI/assistant in its answers either, since that phrasing would
leak into the chat replies shown on screen.
"""
import os
import json
import google.generativeai as genai

genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

_MODEL_NAME = "gemini-3.6-flash"

_RESPONSE_SHAPE = """Respond with ONLY a JSON object, no markdown fences, no preamble, \
matching exactly this shape:
{
  "identified": true or false,
  "brand_name": "string",
  "generic_name": "string",
  "category": "one of: Fever & Pain, Allergy, Digestive, Antibiotic, Vitamins, Cold & Flu, Other",
  "purpose": {"en": "1-2 plain sentences", "ur": "same meaning in Urdu script"},
  "dosage": {"en": "adult dosage guidance, 1-2 sentences", "ur": "same in Urdu"},
  "precaution": {"en": "key warning, 1 sentence", "ur": "same in Urdu"}
}"""

_IMAGE_LOOKUP_SYSTEM = f"""You identify medicines from a photo of a pack, blister strip, \
bottle, or box. Read any printed text (brand name, generic name, dosage) if it's \
legible. If the text is blurry, glared-out, or unreadable, use visual characteristics \
instead: pack color scheme, blister foil pattern, tablet/capsule shape and color, \
box design, logo style - and make your best educated guess at what medicine or \
medicine category this most likely is.

{_RESPONSE_SHAPE}

Rules:
- If you can read the name clearly: identified=true, normal confident answer.
- If you're guessing mainly from visual appearance (not text): identified=true, but \
prefix brand_name with "Possibly: " and keep dosage guidance general rather than a \
specific number (e.g. "follow package directions or ask a pharmacist").
- If the photo doesn't show a medicine pack at all, or you genuinely cannot tell \
anything useful about it: identified=false, brand_name="Unable to identify", \
generic_name="Unknown", category="Other", and purpose/dosage/precaution should each \
contain a short bilingual note advising the user to try a clearer photo or ask a \
pharmacist directly.
- Never invent a specific dosage number you are not reasonably confident about."""

_TEXT_LOOKUP_SYSTEM = f"""You identify medicines from a spoken or typed name, which may \
be misspelled, phonetically transcribed, or in Urdu-accented English (this came from a \
voice recording converted to text, so expect imperfect transcription - e.g. "panadole" \
or "brufin" instead of "Panadol"/"Brufen"). Use your best judgement to match it to the \
most likely real medicine name.

{_RESPONSE_SHAPE}

Rules:
- If you're confident in the match despite transcription noise: identified=true, \
normal confident answer.
- If the name is too garbled or ambiguous to confidently match to one specific \
medicine: identified=true, but prefix brand_name with "Possibly: " and list your best \
guess, keeping dosage guidance general.
- If it doesn't sound like any real medicine name at all: identified=false, \
brand_name="Unable to identify", generic_name="Unknown", category="Other", and \
purpose/dosage/precaution should each contain a short bilingual note asking the user \
to try again more clearly or spell it out.
- Never invent a specific dosage number you are not reasonably confident about."""

_CHAT_SYSTEM_TMPL = """You are the in-app assistant for MediScan, a medicine-identification \
app. The user is looking at the medicine below and asked a follow-up question. Answer \
briefly (2-4 sentences), in {lang_name}, in plain language, as if you are the app itself \
answering - do not refer to yourself as an AI, a language model, or an assistant. You are \
not a doctor: for anything about drug interactions, dosing for children/pregnancy, or \
symptoms that sound serious, tell them to confirm with a pharmacist or doctor rather than \
guessing.

Medicine on screen:
{medicine_json}"""


def _strip_json_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return text.strip()


class AiQuotaError(Exception):
    """Raised when the Gemini API rejects a call for hitting a rate/quota
    limit (HTTP 429), so app.py can return a clean, user-facing message
    instead of the raw provider error text."""
    pass


def _call_gemini(fn, *args, **kwargs):
    """Runs a Gemini call and re-raises quota/rate-limit failures as
    AiQuotaError so callers (app.py) can handle them distinctly from other
    failures (bad image, network issue, etc)."""
    try:
        return fn(*args, **kwargs)
    except Exception as exc:  # noqa: BLE001
        msg = str(exc)
        if "429" in msg or "quota" in msg.lower() or "rate limit" in msg.lower():
            raise AiQuotaError(
                "The identification service is temporarily busy (rate/quota "
                "limit reached). Please try again shortly."
            ) from exc
        raise


def ai_identify_medicine_from_image(image_bytes: bytes, mime_type: str) -> dict:
    model = genai.GenerativeModel(
        model_name=_MODEL_NAME,
        system_instruction=_IMAGE_LOOKUP_SYSTEM,
        generation_config={"response_mime_type": "application/json"},
    )
    image_part = {"mime_type": mime_type, "data": image_bytes}

    def _run():
        resp = model.generate_content(
            [image_part, "Identify the medicine shown in this photo."]
        )
        return json.loads(_strip_json_fences(resp.text))

    return _call_gemini(_run)


def ai_identify_medicine_from_text(name: str) -> dict:
    model = genai.GenerativeModel(
        model_name=_MODEL_NAME,
        system_instruction=_TEXT_LOOKUP_SYSTEM,
        generation_config={"response_mime_type": "application/json"},
    )

    def _run():
        resp = model.generate_content(f'Transcribed name: "{name}"')
        return json.loads(_strip_json_fences(resp.text))

    return _call_gemini(_run)


def ai_chat_reply(message: str, history: list, lang: str, medicine: dict | None) -> str:
    lang_name = "Urdu" if lang == "ur" else "English"
    system = _CHAT_SYSTEM_TMPL.format(
        lang_name=lang_name,
        medicine_json=json.dumps(medicine, ensure_ascii=False) if medicine else "none shown",
    )
    model = genai.GenerativeModel(model_name=_MODEL_NAME, system_instruction=system)

    gemini_history = [
        {
            "role": "model" if h.get("role") == "assistant" else "user",
            "parts": [h.get("text", "")],
        }
        for h in history
        if h.get("text")
    ]
    chat = model.start_chat(history=gemini_history)

    def _run():
        resp = chat.send_message(message)
        return resp.text

    return _call_gemini(_run)