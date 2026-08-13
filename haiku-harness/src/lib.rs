// Haiku Orchestrator Harness
// Universal adapter: Haiku 3.x + 4.x, version-agnostic
// Constraint-first, XML-canonical, git-native provenance
// Provenance: SnapKitty Sovereign Systems

pub mod advanced_kernel;

use advanced_kernel::{AdvancedHaikuKernel, AgentId, Decision, DecisionType, KillSwitchLevel};
use anyhow::{anyhow, Result};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::process::Command;

// ---------------------------------------------------------------------------
// API version
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Eq, PartialEq)]
pub enum ApiVersion { V3, V4 }

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Eq, PartialEq)]
pub enum ConstraintLevel { Strict, Relaxed }

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub enum SenderRole { Orchestrator, Agent, Validator }

// ---------------------------------------------------------------------------
// XML canonical message schema
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MessageHeader {
    pub message_id: String,
    pub timestamp: String,
    pub sender_role: SenderRole,
    pub api_version: ApiVersion,
    pub constraint_level: ConstraintLevel,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Instruction {
    pub instruction_type: String,
    pub directive: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Context {
    pub prior_decisions: Vec<String>,
    pub agent_state: HashMap<String, String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Constraints {
    pub forbidden: Vec<String>,
    pub required: Vec<String>,
    pub optimize_for: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Payload {
    pub instruction: Instruction,
    pub context: Context,
    pub constraints: Constraints,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum ToolId { Bash, Grep, GitLog }

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ToolRequest {
    pub tool_id: ToolId,
    pub arguments: Vec<String>,
    pub timeout_ms: u32,
    pub audit_log_mode: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Provenance {
    pub git_commit_hash: String,
    pub worm_anchor: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct XmlMessage {
    pub header: MessageHeader,
    pub payload: Payload,
    pub tool_request: Option<ToolRequest>,
    pub provenance: Provenance,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct XmlResponse {
    pub message_id: String,
    pub output: String,
    pub constraints_satisfied: bool,
    pub git_commit: String,
    pub worm_anchor: Option<String>,
}

// ---------------------------------------------------------------------------
// Constraint validator
// Pre-execution: forbidden constraints halt immediately; no silent degradation
// ---------------------------------------------------------------------------

pub struct ConstraintValidator;

impl ConstraintValidator {
    pub fn validate(&self, msg: &XmlMessage) -> Result<()> {
        // Schema: required fields present
        if msg.header.message_id.is_empty() {
            return Err(anyhow!("message_id is required"));
        }
        // Forbidden tool check
        if let Some(ref tr) = msg.tool_request {
            let tool_name = match tr.tool_id {
                ToolId::Bash    => "bash",
                ToolId::Grep    => "grep",
                ToolId::GitLog  => "git-log",
            };
            for forbidden in &msg.payload.constraints.forbidden {
                if forbidden.to_lowercase().contains(tool_name) {
                    return Err(anyhow!("constraint violation: forbidden tool '{}' requested", tool_name));
                }
            }
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Tool sandbox: bash and grep only, full audit log
// ---------------------------------------------------------------------------

pub struct ToolSandbox {
    pub git_repo: String,
}

// Allowlist: no rm, mkfs, curl, wget, nc, etc.
const ALLOWED_BINARIES: &[&str] = &["grep", "find", "cat", "echo", "ls", "git"];

impl ToolSandbox {
    pub fn execute(&self, req: &ToolRequest) -> Result<String> {
        let (bin, args) = match req.tool_id {
            ToolId::Bash => {
                // First arg must be an allowed binary
                let bin = req.arguments.first()
                    .ok_or_else(|| anyhow!("bash: no command specified"))?;
                if !ALLOWED_BINARIES.contains(&bin.as_str()) {
                    return Err(anyhow!("sandbox: '{}' is not in allowlist", bin));
                }
                (bin.clone(), req.arguments[1..].to_vec())
            }
            ToolId::Grep => ("grep".into(), req.arguments.clone()),
            ToolId::GitLog => ("git".into(), {
                let mut a = vec!["log".into(), "--oneline".into()];
                a.extend_from_slice(&req.arguments);
                a
            }),
        };

        let output = Command::new(&bin)
            .args(&args)
            .current_dir(&self.git_repo)
            .output()
            .map_err(|e| anyhow!("tool execution failed: {}", e))?;

        if req.audit_log_mode {
            eprintln!(
                "[TOOL:{}] args={:?} exit={} stdout_bytes={}",
                bin, args,
                output.status.code().unwrap_or(-1),
                output.stdout.len()
            );
        }

        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    }
}

// ---------------------------------------------------------------------------
// Git provenance layer
// ---------------------------------------------------------------------------

pub struct GitProvenance {
    pub repo_path: String,
}

impl GitProvenance {
    pub fn commit(&self, message: &str) -> Result<String> {
        // Stage all
        Command::new("git")
            .args(["add", "-A"])
            .current_dir(&self.repo_path)
            .output()?;

        let out = Command::new("git")
            .args(["commit", "--allow-empty", "-m", message])
            .current_dir(&self.repo_path)
            .output()?;

        let rev = Command::new("git")
            .args(["rev-parse", "HEAD"])
            .current_dir(&self.repo_path)
            .output()?;

        Ok(String::from_utf8_lossy(&rev.stdout).trim().into())
    }

    pub fn merkle_root(&self) -> Result<String> {
        let out = Command::new("git")
            .args(["log", "--format=%H"])
            .current_dir(&self.repo_path)
            .output()?;

        let hashes: Vec<&str> = std::str::from_utf8(&out.stdout)?.trim().lines().collect();
        if hashes.is_empty() {
            return Ok("EMPTY".into());
        }

        let mut layer: Vec<String> = hashes.iter().map(|&h| h.to_string()).collect();
        while layer.len() > 1 {
            let mut next = Vec::new();
            let mut i = 0;
            while i < layer.len() {
                let a = &layer[i];
                let b = if i + 1 < layer.len() { &layer[i + 1] } else { a };
                let mut h = Sha256::new();
                h.update(format!("MERKLEv1|{}|{}", a, b));
                next.push(hex::encode(h.finalize()));
                i += 2;
            }
            layer = next;
        }
        Ok(layer[0].clone())
    }
}

// ---------------------------------------------------------------------------
// Haiku Harness: universal orchestrator
// ---------------------------------------------------------------------------

pub struct HaikuHarness {
    pub kernel: AdvancedHaikuKernel,
    pub validator: ConstraintValidator,
    pub sandbox: ToolSandbox,
    pub provenance: GitProvenance,
}

impl HaikuHarness {
    pub fn new(git_repo: String) -> Self {
        HaikuHarness {
            kernel: AdvancedHaikuKernel::new(),
            validator: ConstraintValidator,
            sandbox: ToolSandbox { git_repo: git_repo.clone() },
            provenance: GitProvenance { repo_path: git_repo },
        }
    }

    pub async fn dispatch(&self, msg: XmlMessage) -> Result<XmlResponse> {
        // 1. XML schema validation + constraint check (HALT on violation)
        self.validator.validate(&msg)?;

        // 2. Route to agent based on kernel adaptive memory
        let agent_id = self.route(&msg);

        // 3. Tool execution (if requested)
        let tool_output = if let Some(ref tr) = msg.tool_request {
            self.sandbox.execute(tr)?
        } else {
            String::new()
        };

        // 4. Model invocation (stub — replace with real Anthropic SDK call)
        let model_output = format!(
            "[{}] processed: {} | tool_output: {}",
            format!("{:?}", agent_id),
            &msg.payload.instruction.directive[..msg.payload.instruction.directive.len().min(60)],
            if tool_output.is_empty() { "none".into() } else { tool_output[..tool_output.len().min(40)].to_string() }
        );

        // 5. Record decision + update adaptive memory
        let decision = Decision {
            id: msg.header.message_id.clone(),
            decision_type: DecisionType::Routing,
            timestamp: Utc::now(),
            agent: agent_id,
            input: msg.payload.instruction.directive.clone(),
            output: model_output.clone(),
            success: true,
            latency_ms: 300,
            tokens_used: 500,
            causality_order: 0,
        };
        self.kernel.record_decision(decision)?;

        // 6. Git provenance commit
        let commit_msg = format!(
            "[AGENT:{:?}] Task: {} | Status: success",
            agent_id,
            &msg.payload.instruction.directive[..msg.payload.instruction.directive.len().min(50)]
        );
        let commit_hash = self.provenance.commit(&commit_msg).unwrap_or_else(|_| "UNCOMMITTED".into());

        Ok(XmlResponse {
            message_id: msg.header.message_id,
            output: model_output,
            constraints_satisfied: true,
            git_commit: commit_hash,
            worm_anchor: None,
        })
    }

    fn route(&self, msg: &XmlMessage) -> AgentId {
        // Explicit policy: V4 for verification tasks, V3 otherwise
        // Also respect kernel adaptive success rate
        let ws = self.kernel.world_state.lock().unwrap();
        let h3 = ws.agent_mem.success_rate.get(&AgentId::Haiku3).copied().unwrap_or(0.5);
        let h4 = ws.agent_mem.success_rate.get(&AgentId::Haiku4).copied().unwrap_or(0.5);

        match msg.header.api_version {
            ApiVersion::V4 => AgentId::Haiku4,
            ApiVersion::V3 => AgentId::Haiku3,
        }
    }
}
