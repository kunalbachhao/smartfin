# ─────────────────────────────────────────────
# ai_api.py
# ─────────────────────────────────────────────
from pathlib import Path
from typing import Any, Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib

# ── Paths & Globals ──
BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "model.pkl"

pipeline = None

# ── FastAPI App ──
app = FastAPI(title="Bank SMS Category API")

# ── Request Model ──
class SmsRequest(BaseModel):
    sms: str

# ── Load Model on Startup ──
@app.on_event("startup")
def load_model() -> None:
    global pipeline
    try:
        pipeline = joblib.load(MODEL_PATH)
        print("✅ model.pkl loaded successfully")
    except Exception as e:
        print(f"❌ Failed to load model.pkl: {e}")
        raise

# ── Root Endpoint ──
@app.get("/")
def root() -> Dict[str, Any]:
    return {
        "message": "Bank SMS Category API is running",
        "model_loaded": pipeline is not None,
        "endpoints": {
            "health": "GET /health",
            "predict": "POST /predict"
        }
    }

# ── Health Check ──
@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "model_loaded": pipeline is not None
    }

# ── Prediction Endpoint ──
@app.post("/predict")
def predict(req: SmsRequest) -> Dict[str, Any]:
    global pipeline

    sms = (req.sms or "").strip()
    if not sms:
        raise HTTPException(status_code=400, detail="sms is required")

    if pipeline is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")

    try:
        # Predict category
        category = pipeline.predict([sms])[0]

        # Get top probabilities if available
        probabilities = None
        if hasattr(pipeline, "predict_proba"):
            probs = pipeline.predict_proba([sms])[0]
            clf = getattr(pipeline, "named_steps", {}).get("clf", None)
            classes = list(getattr(clf, "classes_", [])) if clf else []
            if classes:
                paired = sorted(
                    [{"category": str(c), "probability": float(p)} for c, p in zip(classes, probs)],
                    key=lambda x: x["probability"],
                    reverse=True
                )
                probabilities = paired[:5]

        return {
            "success": True,
            "sms": sms,
            "predicted_category": str(category),
            "top_probabilities": probabilities
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")