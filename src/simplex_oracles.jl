
"""
    UnitSimplexOracle(right_side)

Represents the scaled unit simplex:
```
C = {x ∈ R^n_+, ∑x ≤ right_side}
```
"""
struct UnitSimplexOracle{T} <: LinearMinimizationOracle
    right_side::T
end

UnitSimplexOracle{T}() where {T} = UnitSimplexOracle{T}(one(T))

UnitSimplexOracle(rhs::Integer) = UnitSimplexOracle{Rational{BigInt}}(rhs)

"""
LMO for scaled unit simplex:
`∑ x_i ≤ τ`
Returns either vector of zeros or vector with one active value equal to RHS if
there exists an improving direction.
"""
function compute_extreme_point(lmo::UnitSimplexOracle{T}, direction; v=nothing, kwargs...) where {T}
    idx = argmin_(direction)
    if direction[idx] < 0
        return ScaledHotVector(lmo.right_side, idx, length(direction))
    end
    return ScaledHotVector(zero(T), idx, length(direction))
end

function convert_mathopt(
    lmo::UnitSimplexOracle{T},
    optimizer::OT;
    dimension::Integer,
    use_modify::Bool=true,
    kwargs...,
) where {T,OT}
    MOI.empty!(optimizer)
    τ = lmo.right_side
    n = dimension
    (x, _) = MOI.add_constrained_variables(optimizer, [MOI.Interval(0.0, τ) for _ in 1:n])
    #(x, _) = MOI.add_constrained_variables(optimizer, [MOI.Interval(0.0, 1.0) for _ in 1:n])
    MOI.add_constraint(
        optimizer,
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(ones(n), x), 0.0),
        MOI.LessThan(τ),
    )
    return MathOptLMO(optimizer, use_modify)
end

"""
Dual costs for a given primal solution to form a primal dual pair
for scaled unit simplex.
Returns two vectors. The first one is the dual costs associated with the constraints
and the second is the reduced costs for the variables.
"""
function compute_dual_solution(::UnitSimplexOracle{T}, direction, primalSolution) where {T}
    idx = argmax(primalSolution)
    critical = min(direction[idx], 0)
    lambda = [critical]
    mu = direction .- lambda
    return lambda, mu
end

is_decomposition_invariant_oracle(::UnitSimplexOracle) = true

function compute_inface_extreme_point(lmo::UnitSimplexOracle{T}, direction, x; kwargs...) where {T}
    # faces for the unit simplex are:
    # - coordinate faces: {x_i = 0}
    # - simplex face: {∑ x == τ}

    # zero-vector x means fixing to all coordinate faces, return zero-vector
    sx = sum(x)
    if sx <= 0
        return ScaledHotVector(zero(T), 1, length(direction))
    end

    min_idx = -1
    min_val = convert(float(eltype(direction)), Inf)
    # TODO implement with sparse indices of x
    @inbounds for idx in eachindex(direction)
        val = direction[idx]
        if val < min_val && x[idx] > 0
            min_val = val
            min_idx = idx
        end
    end
    # all vertices are on the simplex face except 0
    # if no index better than 0 on the current face, return an all-zero vector
    if sx ≉ lmo.right_side && min_val > 0
        return ScaledHotVector(zero(T), 1, length(direction))
    end
    # if we are on the simplex face or if a vector is better than zero, return the best scaled hot vector
    return ScaledHotVector(lmo.right_side, min_idx, length(direction))
end

function dicg_maximum_step(::UnitSimplexOracle{T}, direction, x) where {T}
    # the direction should never violate the simplex constraint because it would correspond to a gamma_max > 1
    gamma_max = one(promote_type(T, eltype(direction)))
    @inbounds for idx in eachindex(x)
        di = direction[idx]
        if di > 0
            gamma_max = min(gamma_max, x[idx] / di)
        end
    end
    return gamma_max
end

function dicg_maximum_step(
    ::UnitSimplexOracle{T}, 
    direction::SparseArrays.AbstractSparseVector, 
    x,
) where {T}
    gamma_max = one(promote_type(T, eltype(direction)))
    dinds = SparseArrays.nonzeroinds(direction)
    dvals = SparseArrays.nonzeros(direction)
    @inbounds for idx in 1:SparseArrays.nnz(direction)
        di = dvals[idx]
        if di > 0
            gamma_max = min(gamma_max, x[dinds[idx]] / di)
        end
    end
    return gamma_max
end

"""
    ProbabilitySimplexOracle(right_side)

Represents the scaled probability simplex:
```
C = {x ∈ R^n_+, ∑x = right_side}
```
"""
struct ProbabilitySimplexOracle{T} <: LinearMinimizationOracle
    right_side::T
end

ProbabilitySimplexOracle{T}() where {T} = ProbabilitySimplexOracle{T}(one(T))

ProbabilitySimplexOracle(rhs::Integer) = ProbabilitySimplexOracle{Float64}(rhs)

"""
LMO for scaled probability simplex.
Returns a vector with one active value equal to RHS in the
most improving (or least degrading) direction.
"""
function compute_extreme_point(
    lmo::ProbabilitySimplexOracle{T},
    direction;
    v=nothing,
    kwargs...,
) where {T}
    idx = argmin_(direction)
    if idx === nothing
        @show direction
    end
    return ScaledHotVector(lmo.right_side, idx, length(direction))
end

is_decomposition_invariant_oracle(::ProbabilitySimplexOracle) = true

function compute_inface_extreme_point(lmo::ProbabilitySimplexOracle{T}, direction, x::SparseArrays.AbstractSparseVector; kwargs...) where {T}
    # faces for the probability simplex are {x_i = 0}
    min_idx = -1
    min_val = convert(float(eltype(direction)), Inf)
    x_inds = SparseArrays.nonzeroinds(x)
    x_vals = SparseArrays.nonzeros(x)
    @inbounds for idx in eachindex(x_inds)
        val = direction[x_inds[idx]]
        if val < min_val && x_vals[idx] > 0 
            min_val = val
            min_idx = idx
        end
    end
    return ScaledHotVector(lmo.right_side, x_inds[min_idx], length(direction))
end

function dicg_maximum_step(::ProbabilitySimplexOracle{T}, direction, x) where {T}
    gamma_max = one(promote_type(T, eltype(direction)))
    @inbounds for idx in eachindex(x)
        di = direction[idx]
        if di > 0
            gamma_max = min(gamma_max, x[idx] / di)
        end
    end
    return gamma_max
end

function convert_mathopt(
    lmo::ProbabilitySimplexOracle{T},
    optimizer::OT;
    dimension::Integer,
    use_modify=true::Bool,
    kwargs...,
) where {T,OT}
    MOI.empty!(optimizer)
    τ = lmo.right_side
    n = dimension
    (x, _) = MOI.add_constrained_variables(optimizer, [MOI.Interval(0.0, τ) for _ in 1:n])
    #(x, _) = MOI.add_constrained_variables(optimizer, [MOI.Interval(0.0, 1.0) for _ in 1:n])
    MOI.add_constraint(
        optimizer,
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(ones(n), x), 0.0),
        MOI.EqualTo(τ),
    )
    return MathOptLMO(optimizer, use_modify)
end

"""
Dual costs for a given primal solution to form a primal dual pair
for scaled probability simplex.
Returns two vectors. The first one is the dual costs associated with the constraints
and the second is the reduced costs for the variables.
"""
function compute_dual_solution(
    ::ProbabilitySimplexOracle{T},
    direction,
    primal_solution;
    kwargs...,
) where {T}
    idx = argmax(primal_solution)
    lambda = [direction[idx]]
    mu = direction .- lambda
    return lambda, mu
end
