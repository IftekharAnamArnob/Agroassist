# 🌱 AgroAssist

### AI-Powered Plant Disease Identification using Qwen3-VL, LoRA, AgroBench, FastAPI, and Flutter

AgroAssist is an AI-powered mobile application prototype for plant disease identification. The system combines a vision-language foundation model with a Flutter mobile application to analyze plant images and identify diseases from crop-specific candidate diseases.

The project uses **Qwen3-VL-2B-Instruct** as the foundation vision-language model and adapts it to the **Disease Identification (DID)** task of the **AgroBench** benchmark using **LoRA (Low-Rank Adaptation)**.

The final LoRA-adapted model improved held-out Disease Identification accuracy from **39.87% to 67.11%** under the controlled multiple-choice evaluation setup.

---

## 📱 Application Overview

AgroAssist allows a user to:

1. Select a crop.
2. Upload a plant image from the gallery or capture one using the camera.
3. Automatically retrieve diseases associated with the selected crop.
4. Use all disease candidates automatically when the crop contains at most five candidates.
5. Select up to five suspected diseases when a crop contains many possible diseases.
6. Send the image, crop, and candidate diseases to the AI backend.
7. Receive the predicted disease and a short AI-generated explanation.

> **Disclaimer:** AgroAssist is an AI-assisted identification prototype. Important agricultural decisions should be verified with an agricultural professional.

---

## ✨ Key Features

- 📷 Plant image input using **camera or gallery**
- 🌾 Crop selection
- 🦠 Crop-specific disease candidate retrieval
- 🤖 Foundation vision-language model inference
- 🔧 LoRA fine-tuning for agricultural disease identification
- 📱 Flutter-based Android mobile application
- ⚡ FastAPI inference backend
- 🧠 Qwen3-VL-2B-Instruct foundation model
- 🌱 AgroBench Disease Identification dataset
- 💬 Short AI-generated explanation after disease selection
- 🔍 Candidate-constrained inference for more reliable deployment
- ⚠️ Agricultural decision disclaimer

---

## 🏗️ System Architecture

The deployed prototype follows a client-server architecture:

```text
┌───────────────────────────┐
│    AgroAssist Mobile App  │
│         Flutter           │
└─────────────┬─────────────┘
              │
              │ Image + Crop + Candidate Diseases
              ▼
┌───────────────────────────┐
│       FastAPI Backend     │
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│   Crop-Specific Candidate │
│          Retrieval        │
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│    Qwen3-VL-2B-Instruct   │
│       + LoRA Adapter      │
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│ Disease Selection         │
│ + Cautious Explanation    │
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│    Mobile Result Screen   │
└───────────────────────────┘
```

The vision-language model is **not executed directly on the mobile device**. Computationally intensive inference is performed by the backend on a GPU-enabled environment, while the Flutter application acts as the user-facing client.

---

# 📊 Dataset

## AgroBench

AgroAssist uses the **AgroBench** agricultural vision-language benchmark.

AgroBench contains multiple agricultural tasks. This project specifically focuses on:

### Disease Identification (DID)

The DID subset contains:

| Split | Samples |
|---|---:|
| Total DID samples | 1,502 |
| Training | 1,201 |
| Held-out evaluation | 301 |

A reproducible **80/20 split** was created using:

```python
did_split = did_dataset.train_test_split(
    test_size=0.20,
    seed=42
)
```

The same held-out split was used consistently when comparing the base and LoRA-adapted models.

---

# 🤖 Foundation Model

The foundation model used in AgroAssist is:

**Qwen3-VL-2B-Instruct**

Qwen3-VL is a multimodal vision-language model capable of processing both image and text inputs.

In AgroAssist, the model receives:

```text
Plant Image
     +
Crop Information
     +
Candidate Disease Names
```

and selects the most likely disease from the supplied candidates.

---

# 🔧 LoRA Fine-Tuning

Instead of fully fine-tuning the approximately 2B-parameter foundation model, AgroAssist uses **Low-Rank Adaptation (LoRA)**.

LoRA allows the model to be adapted while training only a small fraction of the model parameters.

During the initial LoRA configuration, approximately:

```text
3.21 million trainable parameters
out of approximately 2.13 billion parameters
```

were optimized, representing roughly:

```text
0.15% of the model parameters
```

This substantially reduces training memory and computational requirements compared with full-model fine-tuning.

---

## 🎯 Answer-Only Training

The training pipeline masks the user prompt and image-related prompt tokens so that the loss is calculated primarily on the assistant disease answer.

Example:

```text
Total tokens:       468
Trainable tokens:    12
Masked tokens:      456
```

This encourages the model to learn the target disease response instead of learning to reproduce the entire conversation prompt.

---

# 🧪 Experiments

Several LoRA configurations were evaluated.

| Model | LoRA Rank | Alpha | Epochs | Correct | Accuracy |
|---|---:|---:|---:|---:|---:|
| Base Qwen3-VL-2B | — | — | — | 120 / 301 | 39.87% |
| Qwen3-VL + LoRA | 8 | 16 | 1 | 191 / 301 | 63.46% |
| Qwen3-VL + LoRA | 8 | 16 | 2 | 200 / 301 | 66.45% |
| **Qwen3-VL + LoRA** | **16** | **32** | **2** | **202 / 301** | **67.11%** |

### Final Model

The final model uses:

```text
Foundation Model: Qwen3-VL-2B-Instruct
LoRA Rank:        16
LoRA Alpha:       32
LoRA Dropout:     0.05
Epochs:           2
Learning Rate:    1e-4
Training Samples: 1,201
Evaluation:       301 samples
Split Seed:       42
```

### Improvement

```text
Base Model Accuracy:       39.87%
Fine-Tuned Accuracy:       67.11%
Absolute Improvement:     +27.24 percentage points
```

The final LoRA model correctly classified **82 more samples** than the base model on the same 301-sample held-out evaluation set.

---

# 📈 Evaluation Strategy

A controlled prompt was used to compare the models fairly.

The model was instructed to:

> Select the correct disease from the provided options and respond only with the exact disease name.

The same:

- held-out dataset,
- prompt format,
- option parsing,
- generation configuration, and
- prediction matching procedure

were used when comparing the base and LoRA-adapted models.

This helps ensure that the improvement is attributable to model adaptation rather than a different evaluation format.

---

# 🔬 Error Analysis

The final LoRA model correctly classified:

```text
202 / 301 samples
```

and incorrectly classified:

```text
99 / 301 samples
```

Inspection of incorrect predictions revealed both fine-grained disease confusions and broader misclassifications.

Examples of fine-grained confusion included:

```text
Bacterial blight
→ Bacterial leaf blight
```

Other errors occurred between substantially different disease categories.

This indicates that LoRA adaptation significantly improved Disease Identification performance, while fine-grained visual disease discrimination remains a limitation.

---

# 🌾 Deployment Strategy

During development, unrestricted image-only disease generation was also explored.

The results showed that the adapted model performed substantially better when operating in the constrained Disease Identification format than when generating arbitrary disease names from an image.

Therefore, AgroAssist uses **candidate-constrained inference**.

Instead of asking:

```text
"What disease is this?"
```

the deployed system asks the model to select from a crop-specific set such as:

```text
Crop: Potato

A. Potato Early Blight
B. Potato Late Blight
C. Common scab
D. Black scurf
E. Powdery scab
```

This deployment strategy more closely matches the task format used during model adaptation.

---

# 🌱 Crop-Specific Candidate Retrieval

Disease candidates are retrieved using the crop selected by the user.

The AgroBench DID metadata was used to build a mapping:

```text
Crop → Known Disease Candidates
```

The DID dataset contains **157 unique crop labels** in this mapping.

Candidate handling in the mobile application follows two cases.

### Crops with ≤ 5 disease candidates

All available diseases are automatically considered.

```text
Crop
  ↓
Automatically retrieve candidates
  ↓
Image + candidates
  ↓
Model
```

The user does not need to manually choose diseases.

### Crops with > 5 disease candidates

The user can select up to five suspected diseases before inference.

```text
Crop
  ↓
Retrieve disease list
  ↓
User selects ≤ 5 candidates
  ↓
Image + candidates
  ↓
Model
```

---

# 📊 Candidate-Set Analysis

An additional deployment experiment evaluated the effect of candidate-set size.

| Candidate Set Size | Samples | Correct | Accuracy |
|---|---:|---:|---:|
| 1–5 | 89 | 57 | **64.04%** |
| 6–10 | 86 | 29 | 33.72% |
| 11–15 | 90 | 18 | 20.00% |
| 16+ | 36 | 4 | 11.11% |

The experiment showed that model performance decreases as the number of candidate diseases increases.

This observation directly influenced the mobile deployment strategy, where inference is constrained to at most five candidates.

---

# 💬 AI Explanation

After the disease has been selected, AgroAssist can generate a short explanation describing visual observations that may be consistent with the selected disease.

Disease selection and explanation are intentionally separated:

```text
Stage 1
Candidate-Constrained Disease Selection

              ↓

Stage 2
Short Cautious Explanation
```

The explanation is **supportive information only** and does not alter the disease selected during Stage 1.

The model is instructed to:

- use cautious wording,
- avoid claiming certainty,
- avoid treatment or pesticide recommendations,
- mention that image evidence may be insufficient when appropriate.

Generated explanations may still contain inaccurate visual descriptions and therefore should not be treated as independent diagnostic evidence.

---

# 📱 Mobile Application

The mobile application is developed using **Flutter**.

The application currently provides:

- Crop dropdown
- Automatic disease candidate retrieval
- Manual candidate selection for large candidate sets
- Maximum five-candidate constraint
- Camera image capture
- Gallery image selection
- Image preview
- AI analysis status
- Disease prediction
- AI-generated explanation
- Agricultural disclaimer
- New-diagnosis/reset functionality

---

# ⚡ Backend

The backend is implemented using **FastAPI**.

Main API endpoints include:

| Endpoint | Method | Purpose |
|---|---|---|
| `/` | GET | Backend status |
| `/health` | GET | API/model health |
| `/crops` | GET | Retrieve supported crops |
| `/diseases/{crop}` | GET | Retrieve diseases associated with a crop |
| `/predict` | POST | Perform disease identification |

---

## Prediction Request

The `/predict` endpoint accepts:

```text
image
crop
candidates
```

The candidate list is validated before model inference.

A valid request contains between:

```text
1 and 5 candidate diseases
```

---

## Example Response

```json
{
  "crop": "Potato",
  "candidates": [
    "Potato Early Blight",
    "Potato Late Blight",
    "Common scab"
  ],
  "prediction": "Potato Early Blight",
  "explanation": "The visible symptoms may be consistent with the selected disease, although the image alone is not sufficient for confirmation.",
  "disclaimer": "AI-assisted identification. Verify important decisions with an agricultural professional."
}
```

---

# 📂 Project Structure

```text
Agroassist/
│
├── backend/
│   ├── app.py
│   ├── model_service.py
│   └── crop_to_diseases.json
│
├── frontend/
│   ├── android/
│   ├── assets/
│   │   └── icon/
│   ├── lib/
│   │   └── main.dart
│   ├── test/
│   └── pubspec.yaml
│
├── AgroAssist_Test_Images/
│
├── .gitignore
│
└── README.md
```

Large model checkpoints and LoRA adapter files are intentionally excluded from the Git repository.

---

# 🛠️ Technologies Used

### Machine Learning

- Python
- PyTorch
- Hugging Face Transformers
- PEFT
- LoRA
- Qwen3-VL-2B-Instruct
- AgroBench
- Pillow

### Backend

- FastAPI
- Uvicorn
- Python Multipart

### Mobile Application

- Flutter
- Dart
- HTTP
- Image Picker

### Development / GPU

- Kaggle Notebooks
- NVIDIA GPU
- Cloudflare Tunnel

---

# 🚀 Running the Flutter Application

Navigate to the frontend:

```bash
cd frontend
```

Install dependencies:

```bash
flutter pub get
```

Check available Android devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

> The mobile application requires a running AgroAssist inference backend. The API base URL in the Flutter application must point to the active backend endpoint.

---

# 🖥️ Running the Backend

Navigate to:

```bash
cd backend
```

Create a virtual environment:

```bash
python -m venv venv
```

Activate it on Windows:

```bash
.\venv\Scripts\Activate.ps1
```

Install the API dependencies:

```bash
pip install fastapi uvicorn python-multipart pillow
```

Start the API:

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

### Important

The full Qwen3-VL inference service additionally requires the machine-learning dependencies and the trained LoRA adapter.

The foundation model and LoRA inference are intended to run in a GPU-enabled environment.

---

# ⚠️ Limitations

AgroAssist is a research prototype and has several important limitations.

### 1. Task-Format Dependence

The **67.11%** result represents performance on the custom held-out AgroBench DID multiple-choice evaluation.

It should **not** be interpreted as unrestricted image-only disease diagnosis accuracy or as an official AgroBench leaderboard result.

### 2. Candidate-Set Sensitivity

Performance decreases considerably as the number of candidate diseases increases.

### 3. Explanation Reliability

Generated explanations may occasionally describe visual symptoms incorrectly. They are therefore supportive outputs rather than diagnostic evidence.

### 4. Dataset Scope

The current model adaptation focuses only on the **Disease Identification (DID)** subset of AgroBench.

### 5. Prototype Infrastructure

The current prototype uses a remote GPU inference environment. Temporary development tunnels may change between runtime sessions.

### 6. Agricultural Use

AgroAssist should not be used as the sole basis for important crop-management or treatment decisions.

---

# 🔮 Future Work

Possible future extensions include:

- Support additional AgroBench tasks
- Disease management recommendations
- Pest identification
- Weed identification
- Crop management assistance
- Better candidate retrieval/ranking
- Hierarchical disease classification
- Improved open-ended disease recognition
- Larger-scale model evaluation
- Calibration and uncertainty estimation
- More reliable explanation generation
- Permanent cloud deployment
- iOS support
- On-device inference using smaller/quantized models
- Field testing with real agricultural images

---

# 🧠 Research Summary

The main contribution of AgroAssist is not simply the mobile interface.

The project demonstrates an end-to-end workflow:

```text
Agricultural Benchmark
        ↓
Foundation Vision-Language Model
        ↓
LoRA Adaptation
        ↓
Controlled Evaluation
        ↓
Error / Deployment Analysis
        ↓
Candidate-Constrained Inference
        ↓
FastAPI Backend
        ↓
Flutter Mobile Application
```

The experiments showed that parameter-efficient adaptation substantially improved the foundation model on the selected AgroBench Disease Identification task:

```text
39.87%  →  67.11%
```

Deployment experiments also revealed an important practical limitation: performance decreases as the candidate space becomes larger. The mobile application was therefore designed around constrained crop-specific candidate selection rather than unrestricted disease generation.

---

# 👤 Author

**Iftekhar Anam**

Software Engineering  
Shahjalal University of Science and Technology (SUST)

---

## 📌 Project Status

**Prototype v1.0**

The current version provides an end-to-end Android demonstration of plant disease identification using a LoRA-adapted vision-language foundation model.

---

## 📄 Note

This project was developed as a research-oriented prototype. Model outputs should be interpreted as AI-assisted suggestions rather than confirmed agricultural diagnoses.