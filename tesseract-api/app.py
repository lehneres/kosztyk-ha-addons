import io
from typing import Optional

import pytesseract
import requests
from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from pydantic import BaseModel
from PIL import Image, ImageFilter, ImageOps

app = FastAPI(title="Tesseract OCR API (digits-focused)")


# --- OCR CONFIGS -------------------------------------------------------------

# Main config: line of digits
CFG_PSM7 = "--psm 7 --oem 3 -c tessedit_char_whitelist=0123456789"
# Backup config: single word of digits (sometimes helps)
CFG_PSM8 = "--psm 8 --oem 3 -c tessedit_char_whitelist=0123456789"


def _preprocess(img: Image.Image) -> Image.Image:
    """
    Pre-processing tuned for your small, noisy captcha images.
    - Convert to grayscale
    - Median filter to reduce dotted noise
    - Auto-contrast to separate digits from background
    - Sharpen slightly
    """
    img = img.convert("L")
    img = img.filter(ImageFilter.MedianFilter(size=3))
    img = ImageOps.autocontrast(img)
    img = img.filter(ImageFilter.SHARPEN)
    return img


def _run_tesseract(img: Image.Image, config: str) -> str:
    raw = pytesseract.image_to_string(img, config=config)
    # keep only digits
    digits = "".join(ch for ch in raw if ch.isdigit())
    return digits


def _run_ocr_pipeline(image: Image.Image, expected_length: int = 4) -> str:
    """
    Try a couple of configs and return:
      - a string of digits,
      - or "" if nothing reasonable could be read.

    Strategy:
      1. PSM 7 on preprocessed image.
      2. If not length==expected_length, try PSM 8 on same preprocessed image.
      3. If still not ok, return the longest digits string we saw (may be short).
    """
    img_prep = _preprocess(image)

    candidates = []

    # First attempt: PSM 7 (usually best for your images)
    c1 = _run_tesseract(img_prep, CFG_PSM7)
    candidates.append(c1)
    if len(c1) == expected_length:
        return c1

    # Second attempt: PSM 8 (sometimes recovers missing digits)
    c2 = _run_tesseract(img_prep, CFG_PSM8)
    candidates.append(c2)
    if len(c2) == expected_length:
        return c2

    # Fallback: choose the longest candidate (can still be wrong/short)
    best = max(candidates, key=len, default="")
    # If it's clearly junk (e.g. length 0 or 1), you may prefer to return ""
    if len(best) < expected_length:
        # treat as fail and let the caller decide what to do
        return ""

    return best


# --- REQUEST MODELS ----------------------------------------------------------


class OcrUrlRequest(BaseModel):
    url: str
    expected_length: int = 4


# --- ENDPOINTS ---------------------------------------------------------------


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/ocr/url")
async def ocr_url(payload: OcrUrlRequest):
    """
    Download image from URL and run digits-focused OCR.
    """
    try:
        r = requests.get(payload.url, timeout=10)
        r.raise_for_status()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error downloading image: {e}")

    try:
        image = Image.open(io.BytesIO(r.content))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error reading image: {e}")

    try:
        text = _run_ocr_pipeline(image, expected_length=payload.expected_length)
    except Exception as e:
        # prevent "Empty reply from server": always catch and wrap errors
        raise HTTPException(status_code=500, detail=f"OCR error: {e}")

    return {
        "text": text,
        "length": len(text),
        "expected_length": payload.expected_length,
        "source": "url",
    }


@app.post("/ocr/file")
async def ocr_file(
    file: UploadFile = File(...),
    expected_length: int = Query(4, description="Expected number of digits"),
):
    """
    OCR from uploaded file.

    Example:
      curl -F "file=@captcha.png" \
        "http://HOST:8000/ocr/file?expected_length=4"
    """
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error reading image: {e}")

    try:
        text = _run_ocr_pipeline(image, expected_length=expected_length)
    except Exception as e:
        # Avoid crashing the server → no more curl (52) Empty reply
        raise HTTPException(status_code=500, detail=f"OCR error: {e}")

    return {
        "text": text,
        "length": len(text),
        "expected_length": expected_length,
        "filename": file.filename,
    }

