# Optional trained damage detector

No damage-detection model is bundled. A generic YOLO model cannot be presented as a car-damage detector. To enable: label and train a model on vehicle scratches/dents/panels, evaluate on a withheld test set, save weights, then:

```bash
cd optional_ai
python -m venv .venv
# activate your venv
pip install -r requirements.txt
AI_DAMAGE_WEIGHTS=/path/to/trained-damage.pt uvicorn service:app --host 127.0.0.1 --port 8001
```

On Windows PowerShell use `$env:AI_DAMAGE_WEIGHTS="C:\path\damage.pt"` before `uvicorn`.

The app calls `POST /api/smart/damage`, which forwards to this service. Until configured, returns 503. Human review is mandatory. Use a separate validation plan for before/after damage analysis: this service handles single-image detection only, not photo alignment/change detection.
