# GroqCloud production provider record

Verification date: **2026-10-01**

RepCoach production provider:

    AI_PROVIDER=groq
    GROQ_MODEL=openai/gpt-oss-20b

The API key remains only in the production VPS environment file and is never committed to this repository.

## Endpoint and model

RepCoach uses Groq's OpenAI-compatible Chat Completions endpoint:

    https://api.groq.com/openai/v1/chat/completions

Current model:

    openai/gpt-oss-20b

Groq documents this model as a production model.

Official sources checked on 2026-10-01:

- https://console.groq.com/docs/models
- https://console.groq.com/docs/openai
- https://console.groq.com/docs/your-data
- https://console.groq.com/docs/legal/services-agreement
- https://console.groq.com/docs/legal/ai-policy

## RepCoach data sent to Groq

Only the minimized aggregate workout prompt is sent. The provider prompt may include:

- exercise identifier;
- duration;
- reps and sets;
- target reps and whether the goal was reached;
- placement/pose frame statistics;
- aggregate quality metrics when available.

The prompt excludes:

- name/email/account identity;
- workout ID and exact timestamp;
- routine library;
- full history/PR/badge/streak data;
- camera images or video;
- audio;
- raw pose landmarks;
- per-rep detail list;
- consent/schema metadata.

## Data retention and training

Groq's current data documentation states:

- usage metadata is retained and does not contain customer inputs/outputs;
- inference customer data is not retained by default;
- customer data may be retained when a feature requires it or for platform reliability/troubleshooting/abuse investigation;
- ordinary inference reliability/abuse retention is documented as up to 30 days;
- Zero Data Retention can be enabled in Data Controls;
- RepCoach does not currently claim that ZDR is enabled.

Groq's current Services Agreement states that Inputs/Outputs are not used to train or fine-tune AI models unless the customer explicitly permits or instructs that use.

## End users and age

The current Services Agreement says the customer using Groq Cloud Services must be at least 18. It also expressly allows Groq APIs to be integrated into a Customer Application and AI Model Services to be made available to End Users through that application.

If the Customer Application is directed toward or likely to be accessed by people under the age of majority, the agreement places responsibility on the customer to comply with applicable laws and regulations concerning minors and personal data.

The agreement also says Cloud Services and AI Model Services under that agreement are not for consumer use. RepCoach uses Groq as a backend developer/business service and does not expose a Groq account or API credential directly to end users. If the intended distribution model raises uncertainty about this contractual language, obtain appropriate legal review.

## Medical limitation

Groq's current Services Agreement says AI Model Services should not be used for medical, legal, financial, or other professional advice. RepCoach prompts explicitly request general workout feedback only and prohibit diagnosis or medical advice.

## Production gate

The B7 deploy workflow requires, without printing values:

    AI_PROVIDER=groq
    GROQ_API_KEY=<non-empty>
    GROQ_MODEL=openai/gpt-oss-20b
    BIND_HOST=127.0.0.1

The workflow does not require Gemini billing. The legacy Gemini adapter remains in source for future provider switching but is not the production path.
