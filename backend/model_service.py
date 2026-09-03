
try:
    import torch
    from transformers import Qwen3VLForConditionalGeneration, AutoProcessor
    from peft import PeftModel

    ML_LIBRARIES_AVAILABLE = True

except ImportError:
    torch = None
    Qwen3VLForConditionalGeneration = None
    AutoProcessor = None
    PeftModel = None

    ML_LIBRARIES_AVAILABLE = False


class ModelService:
    def __init__(self, adapter_path):
        self.adapter_path = adapter_path
        self.model = None
        self.processor = None
        self.is_loaded = False

    def load_model(self):
        if not ML_LIBRARIES_AVAILABLE:
            raise RuntimeError(
                "ML libraries are not installed in this environment"
                    )
        
        model_id = "Qwen/Qwen3-VL-2B-Instruct"

        base_model = Qwen3VLForConditionalGeneration.from_pretrained(
            model_id,
            torch_dtype="auto",
            device_map="auto"
        )

        self.processor = AutoProcessor.from_pretrained(
            self.adapter_path
        )

        self.model = PeftModel.from_pretrained(
            base_model,
            self.adapter_path
        )

        self.model.eval()
        self.is_loaded = True
        

    def _prepare_inputs(self, image, prompt):
        image = image.copy()
        image.thumbnail((512, 512))

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": prompt}
                ]
            }
        ]

        text = self.processor.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )

        inputs = self.processor(
            text=[text],
            images=[image],
            padding=True,
            return_tensors="pt"
        )

        inputs = {
            k: v.to(self.model.device)
            if isinstance(v, torch.Tensor)
            else v
            for k, v in inputs.items()
        }

        return inputs

    def predict_disease(self, image, crop, candidates):
        option_letters = ["A", "B", "C", "D", "E"]

        options_text = "\n".join(
            f"{option_letters[i]}. {disease}"
            for i, disease in enumerate(candidates)
        )

        prompt = f"""
Crop: {crop}

Identify the disease visible in the image.

Choose the correct disease from the options below:

{options_text}

Respond with only the exact disease name from the selected option.
Do not provide any explanation.
""".strip()

        inputs = self._prepare_inputs(
            image=image,
            prompt=prompt
        )

        with torch.no_grad():
            generated_ids = self.model.generate(
                **inputs,
                max_new_tokens=20,
                do_sample=False
            )

        generated_ids_trimmed = generated_ids[
            :, inputs["input_ids"].shape[1]:
        ]

        prediction = self.processor.batch_decode(
            generated_ids_trimmed,
            skip_special_tokens=True,
            clean_up_tokenization_spaces=False
        )[0].strip()

        return prediction

    def generate_explanation(self, image, crop, prediction):
        prompt = f"""
Crop: {crop}
Selected disease: {prediction}

Provide a brief, cautious explanation for why the selected disease may match the plant image.

Requirements:
- Keep it to 2 to 3 sentences.
- Mention only symptoms that are actually visible in the image.
- Use cautious wording such as "may be consistent with" or "could indicate".
- Do not claim certainty.
- Do not change the selected disease.
- Do not recommend treatment, pesticides, or chemicals.
- If the visual evidence is weak or unclear, explicitly say that the image alone is not sufficient for confirmation.
""".strip()

        inputs = self._prepare_inputs(
            image=image,
            prompt=prompt
        )

        with torch.no_grad():
            generated_ids = self.model.generate(
                **inputs,
                max_new_tokens=100,
                do_sample=False
            )

        generated_ids_trimmed = generated_ids[
            :, inputs["input_ids"].shape[1]:
        ]

        explanation = self.processor.batch_decode(
            generated_ids_trimmed,
            skip_special_tokens=True,
            clean_up_tokenization_spaces=False
        )[0].strip()

        return explanation

    def predict(self, image, crop, candidates):
        if not self.is_loaded:
            raise RuntimeError("Model is not loaded")

        prediction = self.predict_disease(
            image=image,
            crop=crop,
            candidates=candidates
        )

        explanation = self.generate_explanation(
            image=image,
            crop=crop,
            prediction=prediction
        )

        return {
            "prediction": prediction,
            "explanation": explanation
        }

import os

adapter_path = os.path.join(
    "model",
    "qwen3vl_agrobench_did_lora_r16_2epochs"
)

model_service = ModelService(
    adapter_path=adapter_path
)