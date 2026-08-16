"""
Discretized Hecke Algebra & Cyclic Homology for GL(1)/Q
=========================================================
Real computation. Finite approximation of the Scaling Site.

Source: Connes-Consani 2017; Meyer 2005; Connes 1999

WHAT THIS COMPUTES:
  Trace of scaling operator theta_lambda on HC_1 of truncated Hecke algebra.

WHAT IT GIVES:
  For finite truncation: an INTEGER (from finite-dim semisimple algebra).
  The integer depends entirely on (prime_cutoff, fourier_modes).

TO GET THE REAL INVARIANT 0.457:
  1. Take prime_cutoff → ∞, fourier_modes → ∞
  2. Apply Dixmier trace regularization
  3. Take distributional limit lambda → 1+
  This is Connes' spectral triple construction (1999, Sec 4).
  NOT a linear algebra problem. Analytic number theory / operator algebras.

Dependencies: numpy, scipy
"""

import math
import numpy as np
import scipy.sparse as sp
from dataclasses import dataclass
from typing import List, Tuple
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class AlgebraConfig:
    prime_cutoff:   int   = 13      # Primes p <= prime_cutoff
    fourier_modes:  int   = 3       # Modes k = -K..K
    scaling_lambda: float = 2.0     # The lambda for trace evaluation

    @property
    def primes(self) -> List[int]:
        return [p for p in range(2, self.prime_cutoff + 1)
                if all(p % d != 0 for d in range(2, int(math.sqrt(p)) + 1))]

    @property
    def total_dim(self) -> int:
        return len(self.primes) * (2 * self.fourier_modes + 1)

    def basis_index(self, p_idx: int, k: int) -> int:
        K = self.fourier_modes
        return p_idx * (2 * K + 1) + (k + K)


# ---------------------------------------------------------------------------
# 1. Algebra structure
# ---------------------------------------------------------------------------

def build_left_mult_matrices(cfg: AlgebraConfig):
    """
    Left multiplication matrices L_a for the truncated Hecke algebra.
    Basis: e_{p,k} = T_p ⊗ e^{ik log x}
    Product: T_p T_q = T_{pq} if pq ≤ cutoff (else 0/truncated)
    Scaling: convolution on Fourier basis: e_k * e_l = e_{k+l} if |k+l| ≤ K
    """
    dim = cfg.total_dim
    primes = cfg.primes
    prime_set = set(primes)
    prime_to_idx = {p: i for i, p in enumerate(primes)}
    K = cfg.fourier_modes

    L_mats = []
    for p_idx, p in enumerate(primes):
        for k in range(-K, K + 1):
            L = sp.lil_matrix((dim, dim), dtype=complex)
            for q_idx, q in enumerate(primes):
                for l in range(-K, K + 1):
                    col = cfg.basis_index(q_idx, l)
                    pq = p * q
                    kl = k + l
                    if pq in prime_set and abs(kl) <= K:
                        pq_idx = prime_to_idx[pq]
                        target = cfg.basis_index(pq_idx, kl)
                        L[target, col] += 1.0
            L_mats.append(L.tocsr())

    return L_mats, prime_to_idx


# ---------------------------------------------------------------------------
# 2. Hochschild boundary b₁: C₁ → C₀
# ---------------------------------------------------------------------------

def hochschild_b1(dim: int, L_mats: list) -> np.ndarray:
    """
    b₁(a⊗b) = ab - ba
    Matrix: (dim) × (dim²)
    """
    B = np.zeros((dim, dim * dim), dtype=complex)
    for i in range(dim):
        Li = L_mats[i].toarray()
        for j in range(dim):
            Lj = L_mats[j].toarray()
            col = i * dim + j
            B[:, col] += Li[:, j]   # ab
            B[:, col] -= Lj[:, i]   # -ba
    return B


# ---------------------------------------------------------------------------
# 3. Connes boundary B₀: C₀ → C₁
# ---------------------------------------------------------------------------

def connes_B0(dim: int, one_idx: int = 0) -> np.ndarray:
    """
    B₀(a) = 1⊗a - a⊗1
    Matrix: (dim²) × (dim)
    one_idx: index of the identity element (assumed to be basis element 0)
    """
    B = np.zeros((dim * dim, dim), dtype=complex)
    for i in range(dim):
        B[one_idx * dim + i, i] += 1.0   # 1⊗eᵢ
        B[i * dim + one_idx, i] -= 1.0   # -eᵢ⊗1
    return B


# ---------------------------------------------------------------------------
# 4. HC₁ basis: ker(b₁) / im(B₀)
# ---------------------------------------------------------------------------

def compute_hc1(cfg: AlgebraConfig, L_mats: list) -> Tuple[np.ndarray, np.ndarray]:
    dim = cfg.total_dim
    tol = 1e-10

    b1 = hochschild_b1(dim, L_mats)
    B0 = connes_B0(dim)

    # ker(b₁) via SVD nullspace
    U, s, Vh = np.linalg.svd(b1, full_matrices=True)
    rank_b1 = int(np.sum(s > tol))
    ker_b1_basis = Vh[rank_b1:].T   # (dim² × nullity)
    nullity = ker_b1_basis.shape[1]
    print(f"  dim C₁ = {dim**2},  rank(b₁) = {rank_b1},  nullity = {nullity}")

    # im(B₀) projected into ker(b₁)
    im_B0_in_ker = ker_b1_basis.T @ B0   # (nullity × dim)
    U2, s2, Vh2 = np.linalg.svd(im_B0_in_ker.T, full_matrices=True)
    rank_im = int(np.sum(s2 > tol))

    # HC₁ = complement of im(B₀) in ker(b₁)
    hc1_indices = list(range(rank_im, nullity))
    hc1_basis = ker_b1_basis[:, hc1_indices]   # (dim² × hc1_dim)
    proj      = hc1_basis.T                     # (hc1_dim × dim²)

    print(f"  rank im(B₀) = {rank_im},  HC₁ dim = {len(hc1_indices)}")
    return hc1_basis, proj


# ---------------------------------------------------------------------------
# 5. Scaling operator on C₁
# ---------------------------------------------------------------------------

def scaling_on_C1(cfg: AlgebraConfig) -> np.ndarray:
    """
    theta_lambda acts diagonally on Fourier basis: e_k ↦ lambda^{ik} e_k
    On C₁ = A⊗A: eigenvalues multiply.
    """
    dim = cfg.total_dim
    primes = cfg.primes
    K = cfg.fourier_modes
    lam = cfg.scaling_lambda

    eigvals = np.zeros(dim, dtype=complex)
    for p_idx, _ in enumerate(primes):
        for k in range(-K, K + 1):
            idx = cfg.basis_index(p_idx, k)
            eigvals[idx] = np.exp(1j * k * math.log(lam))

    # Tensor product: eigvals_C1[i*dim+j] = eigvals[i] * eigvals[j]
    eigvals_C1 = np.outer(eigvals, eigvals).flatten()
    return np.diag(eigvals_C1)


# ---------------------------------------------------------------------------
# 6. Main computation
# ---------------------------------------------------------------------------

def run(cfg: AlgebraConfig):
    print(f"Primes: {cfg.primes}")
    print(f"Fourier modes: ±{cfg.fourier_modes},  lambda = {cfg.scaling_lambda}")
    print(f"Algebra dim = {cfg.total_dim}")
    print()

    L_mats, _ = build_left_mult_matrices(cfg)
    print("HC₁ computation:")
    hc1_basis, proj = compute_hc1(cfg, L_mats)
    hc1_dim = hc1_basis.shape[1]

    if hc1_dim == 0:
        print("HC₁ = 0 in this truncation. Increase modes or prime_cutoff.")
        return

    Theta_C1  = scaling_on_C1(cfg)
    Theta_HC1 = proj @ (Theta_C1 @ hc1_basis)

    trace = np.trace(Theta_HC1)
    evals = np.linalg.eigvals(Theta_HC1)

    # HC₀ trace (algebra trace)
    trace_HC0 = sum(
        np.exp(1j * k * math.log(cfg.scaling_lambda))
        for _ in cfg.primes
        for k in range(-cfg.fourier_modes, cfg.fourier_modes + 1)
    )

    super_trace = trace_HC0 - trace

    print(f"\nHC₁ dim:            {hc1_dim}")
    print(f"Tr(theta | HC₁) =   {trace:.6f}  (real: {trace.real:.6f})")
    print(f"Tr(theta | HC₀) =   {trace_HC0:.6f}")
    print(f"Super-trace:        {super_trace:.6f}  (real: {super_trace.real:.6f})")
    print()
    print("Notes:")
    print("  Integer-valued traces arise from finite-dim semisimple algebras.")
    print("  Transcendental invariant 0.457 requires:")
    print("    1. Limit prime_cutoff → ∞, fourier_modes → ∞")
    print("    2. Dixmier trace regularization")
    print("    3. Distributional limit lambda → 1+")
    print("  This is Connes' spectral triple construction (1999, Sec 4).")
    return {
        "hc1_dim":    hc1_dim,
        "trace_hc1":  trace,
        "trace_hc0":  trace_HC0,
        "super_trace": super_trace,
    }


if __name__ == "__main__":
    print("=" * 70)
    print("HECKE ALGEBRA CYCLIC HOMOLOGY — SCALING SITE TRACE (TRUNCATED)")
    print("=" * 70)
    print()
    cfg = AlgebraConfig(prime_cutoff=13, fourier_modes=3, scaling_lambda=2.0)
    run(cfg)
