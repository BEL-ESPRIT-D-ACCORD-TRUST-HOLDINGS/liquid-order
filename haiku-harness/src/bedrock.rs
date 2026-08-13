// Bedrock dispatch layer
// Every agent is Claude Haiku via AWS Bedrock.
// Credentials from ~/.aws/credentials (already configured).
// No API keys in code.
//
// Model IDs:
//   AgentId::Haiku3 -> us.anthropic.claude-haiku-4-5-20251001-v1:0
//   AgentId::Haiku4 -> us.anthropic.claude-haiku-4-5-20251001-v1:0
//   (swap Haiku4 to a different model ID when available)

use crate::advanced_kernel::AgentId;
use anyhow::{anyhow, Result};
use aws_sdk_bedrockruntime::Client;
use aws_sdk_bedrockruntime::primitives::Blob;
use serde_json::{json, Value};

// ---------------------------------------------------------------------------
// Model ID mapping
// All agents route through Bedrock. Swap IDs here when new versions ship.
// ---------------------------------------------------------------------------

pub fn model_id(agent: AgentId) -> &'static str {
    match agent {
        AgentId::Haiku3 => "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        AgentId::Haiku4 => "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    }
}

// ---------------------------------------------------------------------------
// Bedrock client (loads from ~/.aws/credentials, no keys in code)
// ---------------------------------------------------------------------------

pub async fn build_client() -> Client {
    let config = aws_config::load_from_env().await;
    Client::new(&config)
}

// ---------------------------------------------------------------------------
// Invoke a Haiku model via Bedrock
// system_prompt  — sovereign implant system role
// user_message   — the actual payload
// Returns the text content of the first response block.
// ---------------------------------------------------------------------------

pub async fn invoke(
    client: &Client,
    agent: AgentId,
    system_prompt: &str,
    user_message: &str,
) -> Result<BedrockResponse> {
    let model = model_id(agent);

    let body = json!({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4096,
        "temperature": 0,          // deterministic decoder
        "system": system_prompt,
        "messages": [
            { "role": "user", "content": user_message }
        ]
    });

    let raw = client
        .invoke_model()
        .model_id(model)
        .content_type("application/json")
        .body(Blob::new(serde_json::to_vec(&body)?))
        .send()
        .await
        .map_err(|e| anyhow!("Bedrock invoke failed for {}: {}", model, e))?;

    let bytes = raw.body.into_inner();
    let resp: Value = serde_json::from_slice(&bytes)?;

    let text = resp["content"]
        .as_array()
        .and_then(|arr| arr.first())
        .and_then(|block| block["text"].as_str())
        .ok_or_else(|| anyhow!("unexpected Bedrock response shape: {}", resp))?
        .to_string();

    let input_tokens = resp["usage"]["input_tokens"].as_u64().unwrap_or(0) as u32;
    let output_tokens = resp["usage"]["output_tokens"].as_u64().unwrap_or(0) as u32;

    Ok(BedrockResponse {
        text,
        model_id: model.to_string(),
        input_tokens,
        output_tokens,
    })
}

// ---------------------------------------------------------------------------
// Structured response
// ---------------------------------------------------------------------------

pub struct BedrockResponse {
    pub text: String,
    pub model_id: String,
    pub input_tokens: u32,
    pub output_tokens: u32,
}
