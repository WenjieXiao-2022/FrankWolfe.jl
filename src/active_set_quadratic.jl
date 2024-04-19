
"""
    ActiveSetQuadratic{AT, R, IT}

Represents an active set of extreme vertices collected in a FW algorithm,
along with their coefficients `(λ_i, a_i)`.
`R` is the type of the `λ_i`, `AT` is the type of the atoms `a_i`.
The iterate `x = ∑λ_i a_i` is stored in x with type `IT`.
The objective function is assumed to be of the form `f(x)=½⟨x,Ax⟩+⟨b,x⟩+c`
so that the gradient is simply `∇f(x)=Ax+b`.
"""
struct ActiveSetQuadratic{AT, R <: Real, IT, H} <: AbstractActiveSet{AT,R,IT}
    weights::Vector{R}
    atoms::Vector{AT}
    x::IT
    A::H # Hessian matrix
    b::IT # linear term
    dots_x::Vector{R} # stores ⟨A * x, atoms[i]⟩
    dots_A::Vector{Vector{R}} # stores ⟨A * atoms[j], atoms[i]⟩
    dots_b::Vector{R} # stores ⟨b, atoms[i]⟩
    weights_prev::Vector{R}
    modified::BitVector
end

# ActiveSetQuadratic{AT,R}() where {AT,R} = ActiveSetQuadratic{AT,R,Vector{float(eltype(AT))}}([], [])

# ActiveSetQuadratic{AT}() where {AT} = ActiveSetQuadratic{AT,Float64,Vector{float(eltype(AT))}}()

function ActiveSetQuadratic(tuple_values::AbstractVector{Tuple{R,AT}}, A::H, b) where {AT,R,H}
    n = length(tuple_values)
    weights = Vector{R}(undef, n)
    atoms = Vector{AT}(undef, n)
    dots_x = zeros(R, n)
    dots_A = Vector{Vector{R}}(undef, n)
    dots_b = Vector{R}(undef, n)
    weights_prev = zeros(R, n)
    modified = trues(n)
    @inbounds for idx in 1:n
        weights[idx] = tuple_values[idx][1]
        atoms[idx] = tuple_values[idx][2]
        dots_A[idx] = Vector{R}(undef, idx)
        for idy in 1:idx
            dots_A[idx][idy] = fast_dot(A * atoms[idx], atoms[idy])
        end
        dots_b[idx] = fast_dot(b, atoms[idx])
    end
    x = similar(atoms[1], float(eltype(atoms[1])))
    as = ActiveSetQuadratic{AT,R,typeof(x),H}(weights, atoms, x, A, b, dots_x, dots_A, dots_b, weights_prev, modified)
    compute_active_set_iterate!(as)
    return as
end

function ActiveSetQuadratic{AT,R}(tuple_values::AbstractVector{<:Tuple{<:Number,<:Any}}, A::H, b) where {AT,R,H}
    n = length(tuple_values)
    weights = Vector{R}(undef, n)
    atoms = Vector{AT}(undef, n)
    dots_x = zeros(R, n)
    dots_A = Vector{Vector{R}}(undef, n)
    dots_b = Vector{R}(undef, n)
    weights_prev = zeros(R, n)
    modified = trues(n)
    @inbounds for idx in 1:n
        weights[idx] = tuple_values[idx][1]
        atoms[idx] = tuple_values[idx][2]
        dots_A[idx] = Vector{R}(undef, idx)
        for idy in 1:idx
            dots_A[idx][idy] = fast_dot(A * atoms[idx], atoms[idy])
        end
        dots_b[idx] = fast_dot(b, atoms[idx])
    end
    x = similar(tuple_values[1][2], float(eltype(tuple_values[1][2])))
    as = ActiveSetQuadratic{AT,R,typeof(x),H}(weights, atoms, x, A, b, dots_x, dots_A, dots_b, weights_prev, modified)
    compute_active_set_iterate!(as)
    return as
end

# these three functions do not update the active set iterate

function Base.push!(as::ActiveSetQuadratic, (λ, a))
    dot_x = zero(as.dots_x[end])
    dot_A = similar(as.dots_A[end])
    dot_b = fast_dot(as.b, a)
    Aa = as.A * a
    @inbounds for i in 1:length(as)
        dot_A[i] = fast_dot(Aa, as.atoms[i])
        as.dots_x[i] += λ * dot_A[i]
        dot_x += as.weights[i] * dot_A[i]
    end
    push!(dot_A, fast_dot(a, a))
    dot_x += λ * dot_A[end]
    push!(as.weights, λ)
    push!(as.atoms, a)
    push!(as.dots_x, dot_x)
    push!(as.dots_A, dot_A)
    push!(as.dots_b, dot_b)
    push!(as.weights_prev, λ)
    push!(as.modified, false)
    return as
end

function Base.deleteat!(as::ActiveSetQuadratic, idx)
    @inbounds for i in 1:idx-1
        as.dots_x[i] -= as.weights[idx] * as.dots_A[idx][i]
    end
    @inbounds for i in idx+1:length(as)
        as.dots_x[i] -= as.weights[idx] * as.dots_A[i][idx]
        deleteat!(as.dots_A[i], idx)
    end
    deleteat!(as.weights, idx)
    deleteat!(as.atoms, idx)
    deleteat!(as.dots_x, idx)
    deleteat!(as.dots_A, idx)
    deleteat!(as.dots_b, idx)
    deleteat!(as.weights_prev, idx)
    deleteat!(as.modified, idx)
    return as
end

Base.@propagate_inbounds function Base.setindex!(as::ActiveSetQuadratic, tup::Tuple, idx)
    @boundscheck checkbounds(as, idx)
    @inbounds begin
        as.weights[idx] = tup[1]
        as.atoms[idx] = tup[2]
        as.dots_x[idx] -= as.dots_A[idx][idx]
        for i in 1:idx
            as.dots_A[idx][i] = fast_dot(as.atoms[idx], as.atoms[i])
        end
        for i in idx+1:length(as)
            as.dots_A[i][idx] = fast_dot(as.atoms[i], as.atoms[idx])
        end
        as.dots_x[idx] += as.dots_A[idx][idx]
        as.dots_b[idx] = fast_dot(as.b, as.atoms[idx])
        as.weights_prev[idx] = as.weights[idx]
        as.modified[idx] = false
    end
    return tup
end

function Base.empty!(as::ActiveSetQuadratic)
    empty!(as.atoms)
    empty!(as.weights)
    as.x .= 0
    empty!(as.dots_x)
    empty!(as.dots_A)
    empty!(as.dots_b)
    empty!(as.weights_prev)
    empty!(as.modified)
    return as
end

function active_set_update!(active_set::ActiveSetQuadratic, lambda, atom, renorm=true, idx=nothing; add_dropped_vertices=false, vertex_storage=nothing)
    # rescale active set
    active_set.weights .*= (1 - lambda)
    active_set.weights_prev .*= (1 - lambda)
    active_set.dots_x .*= (1 - lambda)
    # add value for new atom
    if idx === nothing
        idx = find_atom(active_set, atom)
    end
    if idx > 0
        @inbounds active_set.weights[idx] += lambda
        @inbounds active_set.modified[idx] = true
    else
        push!(active_set, (lambda, atom))
    end
    if renorm
        add_dropped_vertices = add_dropped_vertices ? vertex_storage !== nothing : add_dropped_vertices
        active_set_cleanup!(active_set, update=false, add_dropped_vertices=add_dropped_vertices, vertex_storage=vertex_storage)
        active_set_renormalize!(active_set)
    end
    active_set_update_scale!(active_set.x, lambda, atom)
    return active_set
end

function active_set_update_iterate_pairwise!(active_set::ActiveSetQuadratic, x::IT, lambda::Real, fw_atom::A, away_atom::A) where {IT, A}
    idx_fw = find_atom(active_set, fw_atom)
    active_set.modified[idx_fw] = true
    idx_away = find_atom(active_set, away_atom)
    if idx_away > 0 # may have been dropped already
        active_set.modified[idx_away] = true
    end
    @. x += lambda * fw_atom - lambda * away_atom
    return x
end

function active_set_renormalize!(active_set::ActiveSetQuadratic)
    renorm = sum(active_set.weights)
    active_set.weights ./= renorm
    active_set.weights_prev ./= renorm
    # TODO check if it's necessary to recompute dots_x
    # to prevent discrepancy due to numerical errors
    active_set.dots_x ./= renorm
    return active_set
end

function active_set_argmin(active_set::ActiveSetQuadratic, direction)
    valm = typemax(eltype(direction))
    idxm = -1
    idx_modified = findall(active_set.modified)
    @inbounds for idx in idx_modified
        weights_diff = active_set.weights[idx] - active_set.weights_prev[idx]
        for i in 1:idx
            active_set.dots_x[i] += weights_diff * active_set.dots_A[idx][i]
        end
        for i in idx+1:length(active_set)
            active_set.dots_x[i] += weights_diff * active_set.dots_A[i][idx]
        end
    end
    @inbounds for i in eachindex(active_set)
        # val = fast_dot(active_set.atoms[i], direction)
        # XXX direction is not used and assumed to be Ax+b
        val = active_set.dots_x[i] + active_set.dots_b[i]
        if val < valm
            valm = val
            idxm = i
        end
    end
    @inbounds for idx in idx_modified
        active_set.weights_prev[idx] = active_set.weights[idx]
        active_set.modified[idx] = false
    end
    return (active_set[idxm]..., idxm)
end

function active_set_argminmax(active_set::ActiveSetQuadratic, direction; Φ=0.5)
    valm = typemax(eltype(direction))
    valM = typemin(eltype(direction))
    idxm = -1
    idxM = -1
    idx_modified = findall(active_set.modified)
    @inbounds for idx in idx_modified
        weights_diff = active_set.weights[idx] - active_set.weights_prev[idx]
        for i in 1:idx
            active_set.dots_x[i] += weights_diff * active_set.dots_A[idx][i]
        end
        for i in idx+1:length(active_set)
            active_set.dots_x[i] += weights_diff * active_set.dots_A[i][idx]
        end
    end
    @inbounds for i in eachindex(active_set)
        # val = fast_dot(active_set.atoms[i], direction)
        # XXX direction is not used and assumed to be Ax+b
        val = active_set.dots_x[i] + active_set.dots_b[i]
        if val < valm
            valm = val
            idxm = i
        end
        if valM < val
            valM = val
            idxM = i
        end
    end
    @inbounds for idx in idx_modified
        active_set.weights_prev[idx] = active_set.weights[idx]
        active_set.modified[idx] = false
    end
    if idxm == -1 || idxM == -1
        error("Infinite minimum $valm or maximum $valM in the active set. Does the gradient contain invalid (NaN / Inf) entries?")
    end
    return (active_set[idxm]..., idxm, valm, active_set[idxM]..., idxM, valM, valM - valm ≥ Φ)
end
