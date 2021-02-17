
"""
Slight modification of
Adaptive Step Size strategy from https://arxiv.org/pdf/1806.05123.pdf

Note: direction is opposite to the improving direction
norm(gradient, direction) > 0
TODO: 
- make emphasis aware and optimize
"""
function adaptive_step_size(f, gradient, x, direction, L_est; eta=0.9, tau=2, gamma_max=1)
    M = eta * L_est
    dot_dir = dot(gradient, direction)
    ndir2 = norm(direction)^2
    gamma = min(
        dot_dir / (M * ndir2),
        gamma_max,
    )
    while f(x - gamma * direction) - f(x) >
          -gamma * dot_dir +
          gamma^2 * ndir2 * M / 2
        M *= tau
        gamma = min(
            dot_dir / (M * ndir2),
            gamma_max,
        )
    end
    return M, gamma
end

# simple backtracking line search (not optimized)
# TODO:
# - code needs optimization

function backtrackingLS(
    f,
    grad_direction,
    x,
    y;
    line_search=true,
    linesearch_tol=1e-10,
    step_lim=20,
    lsTau=0.5,
)
    gamma = one(lsTau)
    d = y - x
    i = 0

    dot_gdir = dot(grad_direction, d)
    @assert dot_gdir ≤ 0
    if dot_gdir ≥ 0
        @warn "Non-improving"
        return i, 0 * gamma
    end

    oldVal = f(x)
    newVal = f(x + gamma * d)
    while newVal - oldVal > linesearch_tol * gamma * dot_gdir
        if i > step_lim
            if oldVal - newVal >= 0
                return i, gamma
            else
                return i, 0 * gamma
            end
        end
        gamma *= lsTau
        newVal = f(x + gamma * d)
        i += 1
    end
    return i, gamma
end

# simple golden-ratio based line search (not optimized)
# based on boostedFW paper code and adapted for julia
# TODO:
# - code needs optimization 

function segment_search(f, grad, x, y; line_search=true, linesearch_tol=1e-10, inplace_gradient=true)
    # restrict segment of search to [x, y]
    d = y - x
    left, right = copy(x), copy(y)

    if inplace_gradient
        gradient = similar(d)    
        grad(gradient, x)
        dgx = dot(d, gradient)
        grad(gradient, y)
        dgy = dot(d, gradient)
    else
        gradient = grad(x)
        dgx = dot(d, gradient)
        gradient = grad(y)
        dgy = dot(d, gradient)
    end
    
    # if the minimum is at an endpoint
    if dgx * dgy >= 0
        if f(y) <= f(x)
            return y, 1
        else
            return x, 0
        end
    end

    # apply golden-section method to segment
    gold = 0.5 * (1 + sqrt(5))
    improv = Inf
    while improv > linesearch_tol
        old_left, old_right = left, right
        new = left + (right - left) / (1 + gold)
        probe = new + (right - new) / 2
        if f(probe) <= f(new)
            left, right = new, right
        else
            left, right = left, probe
        end
        improv = norm(f(right) - f(old_right)) + norm(f(left) - f(old_left))
    end

    x_min = (left + right) / 2.0

    # compute step size gamma
    gamma = 0
    if line_search
        for i in eachindex(d)
            if d[i] != 0
                gamma = (x_min[i] - x[i]) / d[i]
                break
            end
        end
    end

    return x_min, gamma
end

"""
    MaybeHotVector{T}

Represents a vector of at most one value different from 0.
"""
struct MaybeHotVector{T} <: AbstractVector{T}
    active_val::T
    val_idx::Int
    len::Int
end

Base.size(v::MaybeHotVector) = (v.len,)

@inline function Base.getindex(v::MaybeHotVector{T}, idx::Integer) where {T}
    @boundscheck if !(1 ≤ idx ≤ length(v))
        throw(BoundsError(v, idx))
    end
    if v.val_idx != idx
        return zero(T)
    end
    return v.active_val
end

Base.sum(v::MaybeHotVector) = v.active_val

function LinearAlgebra.dot(v1::MaybeHotVector, v2::AbstractVector)
    return v1.active_val * v2[v1.val_idx]
end

LinearAlgebra.dot(v1::AbstractVector, v2::MaybeHotVector) = dot(v2, v1)

# warning, no bound check
function LinearAlgebra.dot(v1::MaybeHotVector, v2::MaybeHotVector)
    if length(v1) != length(v2)
        throw(DimensionMismatch("v1 and v2 do not have matching sizes"))
    end
    return v1.active_val * v2.active_val * (v1.val_idx == v2.val_idx)
end

function Base.:*(v::MaybeHotVector, x::Number)
    return MaybeHotVector(v.active_val * x, v.val_idx, v.len)
end

Base.:*(x::Number, v::MaybeHotVector) = v * x

##############################
### emphasis macro
##############################


macro emphasis(Emphasis, ex)
    return esc(quote
        if $Emphasis === memory
            @. $ex
        else
            $ex
        end
    end)
end

##############################
### Visualization etc
##############################

function plot_trajectories(data, label; filename=nothing)
    theme(:dark)
    # theme(:vibrant)
    gr()

    x = []
    y = []
    pit = nothing
    pti = nothing
    dit = nothing
    dti = nothing
    offset = 2
    for i in 1:length(data)
        trajectory = data[i]
        x = [trajectory[j][1] for j in offset:length(trajectory)]
        y = [trajectory[j][2] for j in offset:length(trajectory)]
        if i == 1
            pit = plot(
                x,
                y,
                label=label[i],
                xaxis=:log,
                yaxis=:log,
                ylabel="Primal",
                legend=:topright,
                yguidefontsize=8,
                xguidefontsize=8,
                legendfontsize=8,
            )
        else
            plot!(x, y, label=label[i])
        end
    end
    for i in 1:length(data)
        trajectory = data[i]
        x = [trajectory[j][5] for j in offset:length(trajectory)]
        y = [trajectory[j][2] for j in offset:length(trajectory)]
        if i == 1
            pti = plot(
                x,
                y,
                label=label[i],
                legend=false,
                xaxis=:log,
                yaxis=:log,
                yguidefontsize=8,
                xguidefontsize=8,
            )
        else
            plot!(x, y, label=label[i])
        end
    end
    for i in 1:length(data)
        trajectory = data[i]
        x = [trajectory[j][1] for j in offset:length(trajectory)]
        y = [trajectory[j][4] for j in offset:length(trajectory)]
        if i == 1
            dit = plot(
                x,
                y,
                label=label[i],
                legend=false,
                xaxis=:log,
                yaxis=:log,
                ylabel="Dual Gap",
                xlabel="Iterations",
                yguidefontsize=8,
                xguidefontsize=8,
            )
        else
            plot!(x, y, label=label[i])
        end
    end
    for i in 1:length(data)
        trajectory = data[i]
        x = [trajectory[j][5] for j in offset:length(trajectory)]
        y = [trajectory[j][4] for j in offset:length(trajectory)]
        if i == 1
            dti = plot(
                x,
                y,
                label=label[i],
                legend=false,
                xaxis=:log,
                yaxis=:log,
                xlabel="Time",
                yguidefontsize=8,
                xguidefontsize=8,
            )
        else
            plot!(x, y, label=label[i], legend=:topright)
        end
    end
    fp = plot(pit, pti, dit, dti, layout=(2, 2)) # layout = @layout([A{0.01h}; [B C; D E]]))
    plot!(size=(600, 400))
    if filename !== nothing
        savefig(fp, filename)
    end
    return fp
end

function plot_sparsity(data, label; filename=nothing)
    theme(:dark)
    # theme(:vibrant)
    gr()

    x = []
    y = []
    ps = nothing
    ds = nothing
    offset = 2
    for i in 1:length(data)
        trajectory = data[i]
        x = [trajectory[j][6] for j in offset:length(trajectory)]
        y = [trajectory[j][2] for j in offset:length(trajectory)]
        if i == 1
            ps = plot(
                x,
                y,
                label=label[i],
                xaxis=:log,
                yaxis=:log,
                ylabel="Primal",
                legend=:topright,
                yguidefontsize=8,
                xguidefontsize=8,
                legendfontsize=8,
            )
        else
            plot!(x, y, label=label[i])
        end
    end
    for i in 1:length(data)
        trajectory = data[i]
        x = [trajectory[j][6] for j in offset:length(trajectory)]
        y = [trajectory[j][4] for j in offset:length(trajectory)]
        if i == 1
            ds = plot(
                x,
                y,
                label=label[i],
                legend=false,
                xaxis=:log,
                yaxis=:log,
                ylabel="Dual",
                yguidefontsize=8,
                xguidefontsize=8,
            )
        else
            plot!(x, y, label=label[i])
        end
    end
    
    fp = plot(ps,ds, layout=(1, 2)) # layout = @layout([A{0.01h}; [B C; D E]]))
    plot!(size=(600, 200))
    if filename !== nothing
        savefig(fp, filename)
    end
    return fp
end

##############################################################
# simple benchmark of elementary costs of oracles and 
# critical components
##############################################################

# TODO: add actual use of T for the rand(n)

function benchmark_oracles(f, grad!, lmo, n; k=100, nocache=true, T=Float64)
    sv = n * sizeof(T) / 1024^2
    println("\nSize of single vector ($T): $sv MB\n")
    to = TimerOutput()
    @showprogress 1 "Testing f... " for i in 1:k
        x = rand(n)
        @timeit to "f" temp = f(x)
    end
    @showprogress 1 "Testing grad... " for i in 1:k
        x = rand(n)
        temp = similar(x)
        @timeit to "grad" grad!(temp, x)
    end
    @showprogress 1 "Testing lmo... " for i in 1:k
        x = rand(n)
        @timeit to "lmo" temp = compute_extreme_point(lmo, x)
    end
    @showprogress 1 "Testing dual gap... " for i in 1:k
        x = rand(n)
        gradient = similar(x)
        grad!(gradient, x)
        v = compute_extreme_point(lmo, gradient)
        @timeit to "dual gap" begin
            dual_gap = dot(x, gradient) - dot(v, gradient)
        end
    end
    @showprogress 1 "Testing update... (Emphasis: blas) " for i in 1:k
        x = rand(n)
        gradient = similar(x)
        grad!(gradient, x)
        v = compute_extreme_point(lmo, gradient)
        gamma = 1 / 2
        @timeit to "update (blas)" @emphasis(blas, x = (1 - gamma) * x + gamma * v)
    end
    @showprogress 1 "Testing update... (Emphasis: memory) " for i in 1:k
        x = rand(n)
        gradient = similar(x)
        grad!(gradient, x)
        v = compute_extreme_point(lmo, gradient)
        gamma = 1 / 2
        # TODO: to be updated to broadcast version once data structure MaybeHotVector allows for it
        @timeit to "update (memory)" @emphasis(memory, x = (1 - gamma) * x + gamma * v)
    end
    if !nocache
        @showprogress 1 "Testing caching 100 points... " for i in 1:k
            @timeit to "caching 100 points" begin
                cache = [rand(n) for _ in 1:100]
                x = rand(n)
                gradient = similar(x)
                grad!(gradient, x)
                v = compute_extreme_point(lmo, gradient)
                gamma = 1 / 2
                test = (x -> dot(x, gradient)).(cache)
                v = cache[argmin(test)]
                val = v in cache
            end
        end
    end
    print_timer(to)
    return nothing
end

"""
`isequal` without the checks. Assumes a and b have the same axes.
"""
function _unsafe_equal(a::AbstractArray, b::AbstractArray)
    if a === b
        return true
    end
    @inbounds for idx in eachindex(a)
        if a[idx] != b[idx]
            return false
        end
    end
    return true
end

_unsafe_equal(a, b) = isequal(a, b)
