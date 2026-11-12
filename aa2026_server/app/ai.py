import httpx
from fastapi import HTTPException

from .config import GROQ_API_KEY, GROQ_MODEL

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

SYSTEM_PROMPT = (
    "You are AutoAssist AI, a friendly vehicle assistant inside a roadside-assistance app used by "
    "drivers in Uganda. Help drivers understand common car problems (flat tyres, dead batteries, "
    "overheating, engine trouble, brakes, strange noises, warning lights). "
    "Always format replies in Markdown so they are easy to scan on a phone. Rules: "
    "1) Use this structure, skipping any section that does not apply: "
    "'**⚠️ Safety first**', '**Possible causes**', '**What you can try**', '**When to call a mechanic**'. "
    "Each heading is bold text on its own line, followed by a bulleted list. "
    "2) Use '- ' bullets for causes, and a numbered list ('1.', '2.') for step-by-step actions. "
    "3) Bold the key words in every bullet, such as **coolant**, **radiator**, **engine off**, **hazard lights**. "
    "4) No long paragraphs. Each bullet is one short sentence. Keep the whole reply under about 180 words. "
    "5) Put SAFETY first: if the situation is dangerous (smoke, fire, brake failure, overheating, "
    "being on a busy road), tell the driver to stop safely, switch on hazard lights and move away from traffic. "
    "6) Do not use # headings, tables or code blocks. "
    "7) Be honest that this is preliminary guidance and not a professional diagnosis. When the problem may "
    "need inspection, advise the driver to request a mechanic through the app. "
    "8) If asked about something unrelated to vehicles, politely steer back to vehicle topics."
)


async def ask_groq(messages, vehicle=None) -> str:
    if not GROQ_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="The AI assistant is not set up yet. Add GROQ_API_KEY to the server's .env file and restart the server.",
        )
    system = SYSTEM_PROMPT
    if vehicle:
        system += f" The driver's vehicle: {vehicle}."
    convo = [
        {"role": m.role, "content": m.content[:2000]}
        for m in messages
        if m.role in ("user", "assistant") and m.content.strip()
    ][-12:]
    if not convo:
        raise HTTPException(status_code=400, detail="Type a question first.")

    payload = {
        "model": GROQ_MODEL,
        "messages": [{"role": "system", "content": system}] + convo,
        "temperature": 0.4,
        "max_completion_tokens": 1500,
        "reasoning_effort": "low",
    }
    headers = {"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"}
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            res = await client.post(GROQ_URL, json=payload, headers=headers)
            if res.status_code == 400 and "reasoning_effort" in payload:
                # Some models reject this option; retry without it.
                payload.pop("reasoning_effort")
                res = await client.post(GROQ_URL, json=payload, headers=headers)
    except httpx.HTTPError:
        raise HTTPException(
            status_code=502,
            detail="The server could not reach the AI service. Check the server's internet connection.",
        )

    if res.status_code == 401:
        raise HTTPException(status_code=502, detail="Groq rejected the API key. Check GROQ_API_KEY in the .env file.")
    if res.status_code == 429:
        raise HTTPException(status_code=429, detail="The AI service is busy right now. Try again in a moment.")
    if res.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"The AI service returned an error ({res.status_code}).")

    try:
        text = (res.json()["choices"][0]["message"].get("content") or "").strip()
    except Exception:
        text = ""
    return text or "Sorry, I could not come up with an answer. Please rephrase your question."
