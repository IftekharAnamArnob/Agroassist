import json
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from PIL import Image
import io
from model_service import model_service

app = FastAPI(
    title="AgroAssist API",
    version="1.0"
)

with open("crop_to_diseases.json", "r", encoding="utf-8") as f:
    crop_to_diseases = json.load(f)


@app.get("/")
def root():
    return {
        "message": "AgroAssist backend is running"
    }


@app.get("/crops")
def get_crops():
    crops = sorted(crop_to_diseases.keys())

    return {
        "total_crops": len(crops),
        "crops": crops
    }

@app.get("/diseases/{crop}")
def get_diseases(crop: str):
    if crop not in crop_to_diseases:
        raise HTTPException(
            status_code=404,
            detail="Crop not found"
        )

    diseases = crop_to_diseases[crop]

    return {
        "crop": crop,
        "total_diseases": len(diseases),
        "diseases": diseases
    }

@app.post("/predict")
async def predict(
    crop: str = Form(...),
    candidates: str = Form(...),
    image: UploadFile = File(...)
):
    # -------------------------------------------------
    # 1. Check whether the selected crop exists
    # -------------------------------------------------
    if crop not in crop_to_diseases:
        raise HTTPException(
            status_code=404,
            detail="Crop not found"
        )

    # -------------------------------------------------
    # 2. Convert comma-separated candidates to a list
    # -------------------------------------------------
    candidate_list = [
        item.strip()
        for item in candidates.split(",")
        if item.strip()
    ]

    # -------------------------------------------------
    # 3. Validate number of candidates
    # -------------------------------------------------
    if len(candidate_list) == 0:
        raise HTTPException(
            status_code=400,
            detail="At least one candidate disease is required"
        )

    if len(candidate_list) > 5:
        raise HTTPException(
            status_code=400,
            detail="Maximum 5 candidate diseases are allowed"
        )

    # -------------------------------------------------
    # 4. Make sure candidates belong to selected crop
    # -------------------------------------------------
    valid_diseases = crop_to_diseases[crop]

    invalid_candidates = [
        disease
        for disease in candidate_list
        if disease not in valid_diseases
    ]

    if invalid_candidates:
        raise HTTPException(
            status_code=400,
            detail={
                "message": (
                    "One or more candidate diseases are "
                    "not valid for the selected crop"
                ),
                "invalid_candidates": invalid_candidates
            }
        )

    # -------------------------------------------------
    # 5. Read uploaded image
    # -------------------------------------------------
    image_bytes = await image.read()

    try:
        pil_image = Image.open(
            io.BytesIO(image_bytes)
        ).convert("RGB")

    except Exception:
        raise HTTPException(
            status_code=400,
            detail="Invalid image file"
        )

    # -------------------------------------------------
    # 6. Check whether the AI model is available
    # -------------------------------------------------
    if not model_service.is_loaded:
        raise HTTPException(
            status_code=503,
            detail="Model is not loaded yet"
        )

    # -------------------------------------------------
    # 7. Run disease prediction
    # -------------------------------------------------
    try:
        result = model_service.predict(
            image=pil_image,
            crop=crop,
            candidates=candidate_list
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Prediction failed: {str(e)}"
        )

    # -------------------------------------------------
    # 8. Return prediction
    # -------------------------------------------------
    return {
        "crop": crop,
        "candidates": candidate_list,
        "prediction": result["prediction"],
        "explanation": result["explanation"],
        "disclaimer": (
            "AI-assisted identification. "
            "Verify important decisions with an agricultural professional."
        )
    }

@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": model_service.is_loaded
    }