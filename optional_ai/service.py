"""Optional inference bridge — no model is shipped. Supply your own trained car-damage weights.
Run: AI_DAMAGE_WEIGHTS=/path/to/trained-damage.pt uvicorn service:app --port 8001
Do not mistake generic object detectors for damage detectors.
"""
import base64
import io
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from PIL import Image

app = FastAPI(title='DriveDesk Optional Damage Model')
model = None
weights = os.environ.get('AI_DAMAGE_WEIGHTS', '')
if weights and os.path.isfile(weights):
    from ultralytics import YOLO
    model = YOLO(weights)

class Photo(BaseModel):
    image_base64: str

@app.get('/health')
def health():
    return {'ok': True, 'trained_model_loaded': model is not None}

@app.post('/detect')
def detect(photo: Photo):
    if model is None:
        raise HTTPException(status_code=503, detail='Provide a trained vehicle-damage YOLO model in AI_DAMAGE_WEIGHTS.')
    try:
        content = base64.b64decode(photo.image_base64, validate=True)
        if len(content) > 1100000:
            raise ValueError('Image too large')
        image = Image.open(io.BytesIO(content)).convert('RGB')
        if image.width * image.height > 16000000:
            raise ValueError('Image dimensions too large')
        prediction = model.predict(source=image, verbose=False, conf=0.4)[0]
        detections = []
        for obj in prediction.boxes:
            cls = int(obj.cls.item())
            detections.append({'label': prediction.names[cls],
                               'confidence': round(float(obj.conf.item()), 3),
                               'xyxy': [round(float(v), 1) for v in obj.xyxy[0].tolist()]})
        return {'detections': detections, 'method': 'configured_yolo_damage_detector',
                'requires_human_confirmation': True,
                'note': 'Model precision depends on your trained weights. Not proof of customer liability.'}
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f'Invalid image/inference: {str(exc)[:200]}') from exc
