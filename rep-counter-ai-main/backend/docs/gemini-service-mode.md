# Gemini Developer API service-mode verification

Verification date: **2026-10-01**

This record exists because `GEMINI_SERVICE_MODE` is documentation/guard metadata only. A value in `.env` is not evidence that the Google project is actually free or billing-enabled.

## Integration actually used by RepCoach

The current adapter calls the Gemini Developer API `generateContent` endpoint at:

```text
https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
```

It does not use Grounding with Google Search/Maps, the Interactions API, the File API, explicit context caching, or a model-tuning API.

The prompt is built only from the whitelisted aggregate workout summary. Contract metadata such as `schema_version` and `consent_version`, identity, workout history, routines, PR history, badges/streaks, camera data, videos, and raw landmarks are excluded.

## Official sources checked

- Gemini API Additional Terms of Service:
  https://ai.google.dev/gemini-api/terms
- Gemini API billing:
  https://ai.google.dev/gemini-api/docs/billing
- Gemini Developer API zero-data-retention documentation:
  https://ai.google.dev/gemini-api/docs/zdr

The Additional Terms page checked on 2026-10-01 states that its current terms are effective March 23, 2026.

## Terms consequences recorded from the official sources

### Audience and use restrictions

The current Additional Terms say:

- API users must be at least 18;
- API Clients must not be directed toward or likely to be accessed by individuals under 18;
- Google AI Studio and Gemini API are for developers building with Google AI models for professional or business purposes, not consumer use;
- API Clients made available in the EEA, Switzerland, or the UK may use only Paid Services;
- the Services may not be used in clinical practice or to provide medical advice.

These restrictions apply independently of whether a project is on the free or paid tier.

### Unpaid Services

For Unpaid Services, the current Additional Terms state that Google may use submitted content and generated responses to provide, improve, and develop Google products/services and machine-learning technologies. Human reviewers may read, annotate, and process API input/output. The Terms instruct developers not to submit sensitive, confidential, or personal information to Unpaid Services.

The checked terms do not provide an exact general retention duration for ordinary unpaid `generateContent` requests, so RepCoach must not invent one.

### Paid Services

For Paid Services, the current Additional Terms state that Google does not use prompts or responses to improve its products. They also state that Google logs prompts and responses for a limited period for abuse prevention/detection and required legal or regulatory disclosures.

The checked Terms describe that retention as a limited period but do not state a single exact duration for ordinary paid `generateContent` abuse-monitoring logs. RepCoach therefore must not claim a specific retention period unless another applicable official control/source is verified for the deployed project.

The ZDR documentation describes additional controls and an approval path for projects that require zero-data-retention treatment. RepCoach has not established that its production project has ZDR approval and must not claim ZDR.

## Billing-state verification

Google's billing documentation says the project's actual billing tier/status must be checked in Google AI Studio (Projects/Billing). API keys inherit the billing state of their project; an API key does not have independent billing settings.

Therefore source code cannot prove the production mode.

RepCoach's production privacy contract now permits only:

```text
GEMINI_SERVICE_MODE=billing_enabled
```

The adapter rejects `unpaid`, a missing value, or any other value with the generic public `AI_UNAVAILABLE` response. This prevents RepCoach workout summaries from being sent through Gemini Unpaid Services. The value remains a guard/assertion only: the exact Google project's Billing Tier/Plan must still be verified in Google AI Studio before deployment.

## Actual RepCoach production deployment mode

**Status: BILLING-ENABLED REQUIRED BY REPCOACH; EXACT PRODUCTION PROJECT STILL NOT VERIFIED FROM SOURCE — production release blocker.**

The repository does not contain the Google AI Studio project billing state, and this phase has no authenticated access to that billing console. Do not infer the mode from the presence of `GEMINI_API_KEY`, from `.env.example`, or from successful requests.

Before production deployment, an operator with access to the exact Google project used by the production API key must:

1. open Google AI Studio Projects/Billing;
2. verify the exact project's current Billing Tier/Plan;
3. record the result and date in the deployment checklist;
4. proceed only if the project is on a Paid Tier, then set `GEMINI_SERVICE_MODE=billing_enabled`;
5. re-check the current official terms if the verification date is stale.

## Product/terms blocker requiring resolution before production

The current Gemini Developer API terms' 18+ and professional/business-not-consumer restrictions are material to RepCoach. A paid/billing-enabled project changes data-use treatment, but it does **not** by itself remove those audience/use restrictions.

Do not ship the Gemini Developer API integration to a general consumer audience merely because billing is enabled. Before B7 production deployment, product/legal review must establish that the actual RepCoach distribution and audience are permitted under the then-current terms, or Track B must switch to a provider/service whose terms fit the product.

B4 must make the Privacy Policy truthful about the actual provider mode, but policy wording alone is not proof that a deployment satisfies provider terms.

## Data-minimization consequence

For either mode, keep the current aggregate-only prompt boundary. Do not add routine libraries, full workout history, PR history, badge/streak history, identity, camera/video content, or raw landmarks to the provider request.
