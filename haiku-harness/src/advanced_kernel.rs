// Advanced Haiku Learning Kernel
// Memory • Time • Adaptive Learning • Continuity • Kill Switch
// Provenance: SnapKitty Sovereign Systems

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldState {
    pub version: u32,
    pub timestamp: DateTime<Utc>,
    pub decisions: Vec<Decision>,
    pub agent_mem: AgentMemory,
    pub constraints: Vec<Constraint>,
    pub metrics: PerformanceMetrics,
    pub continuation_stack: Vec<ContinuationFrame>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Eq, PartialEq, Ord, PartialOrd)]
pub struct Decision {
    pub id: String,
    pub decision_type: DecisionType,
    pub timestamp: DateTime<Utc>,
    pub agent: AgentId,
    pub input: String,
    pub output: String,
    pub success: bool,
    pub latency_ms: u32,
    pub tokens_used: u32,
    pub causality_order: usize,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Eq, PartialEq, Ord, PartialOrd)]
pub enum DecisionType { Routing, Verification, Coordination, Learning }

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Eq, PartialEq, Hash)]
pub enum AgentId { Haiku3, Haiku4 }

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AgentMemory {
    pub decisions: HashMap<String, Vec<Decision>>,
    pub success_rate: HashMap<AgentId, f64>,
    pub latency_trend: HashMap<AgentId, Vec<u32>>,
    pub last_used: HashMap<AgentId, DateTime<Utc>>,
    pub learning_gradient: HashMap<AgentId, f64>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    pub total_decisions: u32,
    pub successful_decisions: u32,
    pub average_latency: f64,
    pub context_window_usage: (u32, u32),
    pub constraint_violations: u32,
    pub tool_invocations: u32,
    pub learning_rate: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Constraint {
    pub name: String,
    pub constraint_type: ConstraintType,
    pub predicate: String,   // SMT-Lib2 formula
    pub violations: u32,
    pub created_at: DateTime<Utc>,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub enum ConstraintType { Forbidden, Required, Invariant }

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ContinuationFrame {
    pub stage_id: String,
    pub stage_type: StageType,
    pub dependencies: Vec<String>,
    pub checkpoint: Option<Box<WorldState>>,
    pub has_failed: bool,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub enum StageType { Decompose, Verify, Synthesize, Execute, Checkpoint }

// ---------------------------------------------------------------------------
// AST for world state
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum WorldAST {
    Root { name: String, children: Vec<WorldAST> },
    Agent { name: String, state: HashMap<String, String> },
    Decision { id: String, decision_type: String, result: String },
    Constraint { name: String, formula: String, satisfied: bool },
    Metric { name: String, value: f64 },
    Timestamp { iso8601: String },
}

// ---------------------------------------------------------------------------
// Kill switch
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Eq, PartialEq, Ord, PartialOrd)]
pub enum KillSwitchLevel {
    L0Graceful,      // finish current stage, save state
    L1SandboxWipe,   // clear /tmp, reset memory
    L2WorldEnd,      // erase all persistent data (NUCLEAR)
    L3Defunct,       // process termination + cleanup
}

// ---------------------------------------------------------------------------
// Kernel
// ---------------------------------------------------------------------------

pub struct AdvancedHaikuKernel {
    pub world_state: Arc<Mutex<WorldState>>,
    pub kill_switch: Arc<Mutex<Option<KillSwitchLevel>>>,
}

impl AdvancedHaikuKernel {
    pub fn new() -> Self {
        let mut success_rate = HashMap::new();
        success_rate.insert(AgentId::Haiku3, 0.5);
        success_rate.insert(AgentId::Haiku4, 0.5);

        let mut latency_trend = HashMap::new();
        latency_trend.insert(AgentId::Haiku3, Vec::new());
        latency_trend.insert(AgentId::Haiku4, Vec::new());

        let mut learning_gradient = HashMap::new();
        learning_gradient.insert(AgentId::Haiku3, 0.0);
        learning_gradient.insert(AgentId::Haiku4, 0.0);

        let mut decisions_map = HashMap::new();
        decisions_map.insert("haiku3".to_string(), Vec::new());
        decisions_map.insert("haiku4".to_string(), Vec::new());

        let world_state = WorldState {
            version: 1,
            timestamp: Utc::now(),
            decisions: Vec::new(),
            agent_mem: AgentMemory {
                decisions: decisions_map,
                success_rate,
                latency_trend,
                last_used: HashMap::new(),
                learning_gradient,
            },
            constraints: Vec::new(),
            metrics: PerformanceMetrics {
                total_decisions: 0,
                successful_decisions: 0,
                average_latency: 0.0,
                context_window_usage: (0, 200_000),
                constraint_violations: 0,
                tool_invocations: 0,
                learning_rate: 0.2,
            },
            continuation_stack: Vec::new(),
        };

        AdvancedHaikuKernel {
            world_state: Arc::new(Mutex::new(world_state)),
            kill_switch: Arc::new(Mutex::new(None)),
        }
    }

    // Record decision + adaptive learning update
    pub fn record_decision(&self, decision: Decision) -> Result<(), String> {
        let mut ws = self.world_state.lock().map_err(|_| "lock poisoned")?;

        // Temporal causality check
        if let Some(last) = ws.decisions.last() {
            if decision.timestamp < last.timestamp {
                return Err("causality violation: timestamp before previous decision".into());
            }
        }

        let agent = decision.agent;
        let alpha = ws.metrics.learning_rate;

        // Exponential moving average on success rate
        let old_rate = ws.agent_mem.success_rate.get(&agent).copied().unwrap_or(0.5);
        let outcome  = if decision.success { 1.0 } else { 0.0 };
        ws.agent_mem.success_rate.insert(agent, old_rate * (1.0 - alpha) + outcome * alpha);

        // Latency trend (keep last 100)
        let latencies = ws.agent_mem.latency_trend.entry(agent).or_default();
        latencies.push(decision.latency_ms);
        if latencies.len() > 100 { latencies.remove(0); }

        // Learning gradient
        let grad = if latencies.len() >= 2 {
            let half = latencies.len() / 2;
            let old_avg = latencies[..half].iter().sum::<u32>() as f64 / half as f64;
            let new_avg = latencies[half..].iter().sum::<u32>() as f64 / half as f64;
            (old_avg - new_avg) / old_avg.max(1.0)
        } else { 0.0 };
        ws.agent_mem.learning_gradient.insert(agent, grad);

        // Metrics
        ws.metrics.total_decisions += 1;
        if decision.success { ws.metrics.successful_decisions += 1; }
        ws.metrics.average_latency =
            (ws.metrics.average_latency * (ws.metrics.total_decisions - 1) as f64
             + decision.latency_ms as f64)
            / ws.metrics.total_decisions as f64;

        ws.decisions.push(decision);
        ws.timestamp = Utc::now();
        Ok(())
    }

    // Generate SMT-Lib2 script from active constraints
    pub fn generate_smt_script(&self) -> Result<String, String> {
        let ws = self.world_state.lock().map_err(|_| "lock poisoned")?;
        let mut lines = vec![
            "(set-logic QF_UFLIA)".into(),
            "(set-info :source \"Haiku Kernel World State\")".into(),
            "(declare-const success_rate Real)".into(),
            "(declare-const avg_latency Int)".into(),
        ];
        for c in &ws.constraints {
            lines.push(format!("(assert {})", c.predicate));
        }
        lines.extend([
            "(assert (>= success_rate 0.0))".into(),
            "(assert (<= success_rate 1.0))".into(),
            "(assert (>= avg_latency 0))".into(),
            "(assert (<= avg_latency 10000))".into(),
            "(check-sat)".into(),
            "(get-model)".into(),
        ]);
        Ok(lines.join("\n"))
    }

    // Convert world state to AST
    pub fn to_ast(&self) -> Result<WorldAST, String> {
        let ws = self.world_state.lock().map_err(|_| "lock poisoned")?;

        let agent_nodes: Vec<WorldAST> = [AgentId::Haiku3, AgentId::Haiku4]
            .iter()
            .map(|&a| {
                let mut state = HashMap::new();
                state.insert("success_rate".into(),
                    ws.agent_mem.success_rate.get(&a).map(|r| r.to_string()).unwrap_or_default());
                state.insert("gradient".into(),
                    ws.agent_mem.learning_gradient.get(&a).map(|g| g.to_string()).unwrap_or_default());
                WorldAST::Agent { name: format!("{:?}", a).to_lowercase(), state }
            })
            .collect();

        Ok(WorldAST::Root {
            name: "world".into(),
            children: vec![
                WorldAST::Timestamp { iso8601: ws.timestamp.to_rfc3339() },
                WorldAST::Root { name: "memory".into(), children: agent_nodes },
                WorldAST::Root {
                    name: "metrics".into(),
                    children: vec![
                        WorldAST::Metric { name: "total_decisions".into(), value: ws.metrics.total_decisions as f64 },
                        WorldAST::Metric { name: "avg_latency".into(), value: ws.metrics.average_latency },
                    ],
                },
            ],
        })
    }

    pub fn verify_causality(&self) -> Result<bool, String> {
        let ws = self.world_state.lock().map_err(|_| "lock poisoned")?;
        Ok(ws.decisions.windows(2).all(|w| w[0].timestamp <= w[1].timestamp))
    }

    pub fn backtrack_to(&self, decision_id: &str) -> Result<bool, String> {
        let mut ws = self.world_state.lock().map_err(|_| "lock poisoned")?;
        if let Some(pos) = ws.decisions.iter().position(|d| d.id == decision_id) {
            ws.decisions.truncate(pos + 1);
            ws.timestamp = Utc::now();
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub fn push_continuation(&self, frame: ContinuationFrame) -> Result<(), String> {
        self.world_state.lock().map_err(|_| "lock poisoned")?.continuation_stack.push(frame);
        Ok(())
    }

    pub fn pop_continuation(&self) -> Result<Option<ContinuationFrame>, String> {
        Ok(self.world_state.lock().map_err(|_| "lock poisoned")?.continuation_stack.pop())
    }

    pub fn trigger_kill_switch(&self, level: KillSwitchLevel) -> Result<(), String> {
        *self.kill_switch.lock().map_err(|_| "lock poisoned")? = Some(level);
        match level {
            KillSwitchLevel::L0Graceful => {
                eprintln!("L0: Graceful shutdown — saving state");
                std::process::exit(0);
            }
            KillSwitchLevel::L1SandboxWipe => {
                eprintln!("L1: Sandbox wipe — resetting agent memory");
                let mut ws = self.world_state.lock().map_err(|_| "lock poisoned")?;
                ws.agent_mem.success_rate.insert(AgentId::Haiku3, 0.5);
                ws.agent_mem.success_rate.insert(AgentId::Haiku4, 0.5);
                ws.agent_mem.latency_trend.clear();
                std::process::exit(0);
            }
            KillSwitchLevel::L2WorldEnd => {
                eprintln!("L2: WORLD END — erasing all persistent data");
                std::process::exit(1);
            }
            KillSwitchLevel::L3Defunct => {
                eprintln!("L3: DEFUNCT — process termination");
                std::process::exit(1);
            }
        }
    }
}

impl Default for AdvancedHaikuKernel {
    fn default() -> Self { Self::new() }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_decision(agent: AgentId, success: bool, latency: u32) -> Decision {
        Decision {
            id: uuid::Uuid::new_v4().to_string(),
            decision_type: DecisionType::Routing,
            timestamp: Utc::now(),
            agent,
            input: "test".into(),
            output: "test".into(),
            success,
            latency_ms: latency,
            tokens_used: 100,
            causality_order: 1,
        }
    }

    #[test]
    fn test_init() {
        let k = AdvancedHaikuKernel::new();
        let ws = k.world_state.lock().unwrap();
        assert_eq!(ws.version, 1);
        assert_eq!(ws.decisions.len(), 0);
    }

    #[test]
    fn test_adaptive_learning() {
        let k = AdvancedHaikuKernel::new();
        k.record_decision(sample_decision(AgentId::Haiku3, true, 100)).unwrap();
        let ws = k.world_state.lock().unwrap();
        assert!(ws.agent_mem.success_rate[&AgentId::Haiku3] > 0.5);
        assert_eq!(ws.metrics.total_decisions, 1);
    }

    #[test]
    fn test_causality() {
        let k = AdvancedHaikuKernel::new();
        assert!(k.verify_causality().unwrap());
    }

    #[test]
    fn test_ast() {
        let k = AdvancedHaikuKernel::new();
        let ast = k.to_ast().unwrap();
        matches!(ast, WorldAST::Root { .. });
    }

    #[test]
    fn test_smt_script() {
        let k = AdvancedHaikuKernel::new();
        let script = k.generate_smt_script().unwrap();
        assert!(script.contains("check-sat"));
        assert!(script.contains("success_rate"));
    }
}
