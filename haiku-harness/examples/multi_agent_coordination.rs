// Multi-agent coordination example
// Stage 1: Haiku 3 (BOB) decomposes task
// Stage 2: Haiku 4 verifies
// Stage 3: Haiku 3 synthesizes

use haiku_harness::*;
use std::collections::HashMap;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let harness = HaikuHarness::new(".".to_string()).await;

    let stages = [
        ("Decompose task into verification subtasks", ApiVersion::V3),
        ("Verify SEB artifacts (Idris2, Ada, Erlang)", ApiVersion::V4),
        ("Synthesize verification results", ApiVersion::V3),
    ];

    for (i, (directive, version)) in stages.iter().enumerate() {
        let msg = XmlMessage {
            header: MessageHeader {
                message_id: format!("stage-{}", i + 1),
                timestamp: chrono::Utc::now().to_rfc3339(),
                sender_role: SenderRole::Orchestrator,
                api_version: *version,
                constraint_level: ConstraintLevel::Strict,
            },
            payload: Payload {
                instruction: Instruction {
                    instruction_type: if i == 1 { "verification" } else { "task" }.into(),
                    directive: directive.to_string(),
                },
                context: Context {
                    prior_decisions: vec![],
                    agent_state: HashMap::new(),
                },
                constraints: Constraints {
                    forbidden: vec!["curl".into(), "wget".into(), "rm".into()],
                    required: vec!["audit_all_tools".into()],
                    optimize_for: vec!["latency".into()],
                },
            },
            tool_request: None,
            provenance: Provenance {
                git_commit_hash: String::new(),
                worm_anchor: None,
            },
        };

        let response = harness.dispatch(msg).await?;
        println!("Stage {}: {}", i + 1, response.output);
        println!("  git: {}", response.git_commit);
    }

    println!("\nCausality verified: {}", harness.kernel.verify_causality()?);
    println!("SMT script preview:");
    println!("{}", &harness.kernel.generate_smt_script()?[..200.min(harness.kernel.generate_smt_script()?.len())]);

    Ok(())
}
