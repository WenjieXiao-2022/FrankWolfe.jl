
function bcg(
    f,
    grad!,
    lmo,
    x0;
    line_search::LineSearchMethod=adaptive,
    L=Inf,
    epsilon=1e-7,
    max_iteration=10000,
    print_iter=1000,
    trajectory=false,
    verbose=false,
    linesearch_tol=1e-7,
    emphasis::Emphasis=blas,
    Ktolerance=1.0,
    goodstep_tolerance=0.75,
    weight_purge_threshold=1e-9,
    gradient=nothing,
    lmo_kwargs...,
)
    function print_header(data)
        @printf(
            "\n──────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
        )
        @printf(
            "%6s %13s %14s %14s %14s %14s %14s %14s %14s\n",
            data[1],
            data[2],
            data[3],
            data[4],
            data[5],
            data[6],
            data[7],
            data[8],
            data[9],
        )
        @printf(
            "──────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
        )
    end

    function print_footer()
        @printf(
            "──────────────────────────────────────────────────────────────────────────────────────────────────────────────\n\n"
        )
    end

    function print_iter_func(data)
        @printf(
            "%6s %13s %14e %14e %14e %14e %14i %14i %14i\n",
            st[Symbol(data[1])],
            data[2],
            Float64(data[3]),
            Float64(data[4]),
            Float64(data[5]),
            data[6],
            data[7],
            data[8],
            data[9],
        )
    end

    t = 0
    primal = Inf
    dual_gap = Inf
    active_set = ActiveSet([(1.0, x0)])
    x = x0
    if gradient === nothing
        gradient = similar(x)
    end
    grad!(gradient, x)
    # initial gap estimate computation
    vmax = compute_extreme_point(lmo, gradient)
    phi = dot(gradient, x0 - vmax) / 2
    traj_data = []
    tt = regular
    time_start = time_ns()
    v = x0

    if line_search == shortstep && !isfinite(L)
        @error("Lipschitz constant not set to a finite value. Prepare to blow up spectacularly.")
    end

    if line_search == agnostic || line_search == nonconvex
        @error("Lazification is not known to converge with open-loop step size strategies.")
    end

    if verbose
        println("\nBlended Conditional Gradients Algorithm.")
        numType = eltype(x0)
        println(
            "EMPHASIS: $emphasis STEPSIZE: $line_search EPSILON: $epsilon max_iteration: $max_iteration TYPE: $numType",
        )
        println("K: $Ktolerance")
        if emphasis == memory
            println("WARNING: In memory emphasis mode iterates are written back into x0!")
        end
        headers = (
            "Type",
            "Iteration",
            "Primal",
            "Dual",
            "Dual Gap",
            "Time",
            "#ActiveSet",
            "#non-simplex",
            "#forced FW",
        )
        print_header(headers)
    end

    if emphasis == memory && !isa(x, Union{Array, SparseVector})
        x = convert(Vector{promote_type(eltype(x), Float64)}, x)
    end
    non_simplex_iter = 0
    nforced_fw = 0
    force_fw_step = false

    while t <= max_iteration && phi ≥ epsilon
        x = compute_active_set_iterate(active_set)
        # TODO replace with single call interface from function_gradient.jl
        primal = f(x)
        grad!(gradient, x)
        if !force_fw_step
            (idx_fw, idx_as, good_progress) = find_minmax_directions(
                active_set, gradient, phi, goodstep_tolerance=goodstep_tolerance,
            )
        end
        if !force_fw_step && good_progress
            tt = simplex_descent
            force_fw_step = update_simplex_gradient_descent!(
                active_set,
                gradient,
                f,
                L=L,
                weight_purge_threshold=weight_purge_threshold,
            )
            nforced_fw += force_fw_step
        else
            non_simplex_iter += 1
            # compute new atom
            (v, value) = lp_separation_oracle(
                lmo,
                active_set,
                gradient,
                phi,
                Ktolerance;
                inplace_loop=(emphasis == memory),
                force_fw_step=force_fw_step,
                lmo_kwargs...,
            )
            force_fw_step = false
            xval = dot(x, gradient)
            if value > xval - phi
                tt = dualstep
                # setting gap estimate as ∇f(x) (x - v_FW) / 2
                phi = (xval - value) / 2
            else
                active_set_cleanup!(active_set)
                active_set_renormalize!(active_set)
                x = compute_active_set_iterate(active_set)
                tt = regular
                if line_search == agnostic
                    gamma = 2 / (2 + t)
                elseif line_search == goldenratio
                    _, gamma = segment_search(f, grad!, x, ynew, linesearch_tol=linesearch_tol)
                elseif line_search == backtracking
                    _, gamma = backtrackingLS(f, gradient, x, v, linesearch_tol=linesearch_tol, step_lim=100)
                elseif line_search == nonconvex
                    gamma = 1 / sqrt(t + 1)
                elseif line_search == shortstep
                    gamma =  dot(gradient, x - v) / (L * dot(x - v, x - v))
                elseif line_search == adaptive
                    L, gamma = adaptive_step_size(f, gradient, x, x - v, L)
                end
                fprev = f(x)
                fprev2 = f(compute_active_set_iterate(active_set))
                fnew_first = f(
                    compute_active_set_iterate(active_set) - gamma * (x - v)
                )
                norm_x_err = norm(x - compute_active_set_iterate(active_set))
                fnew_first_init = f(x - gamma * (x - v))
                new_iterate_theo = x - gamma * (x - v)
                active_set_update!(active_set, gamma, v)
                new_iterate_real = compute_active_set_iterate(active_set)
                fnew = f(new_iterate_real)
                if fprev <= fnew
                    @debug "val before update $(fprev)"
                    @debug "val before update actual $(fprev2)"
                    @debug "val before update on x $(fnew_first_init)"
                    @debug "val update theory $(fnew_first)"
                    @debug "Gap $(dot(gradient, x - v))"
                    @debug "current x $(sum(x))"
                    @debug "x out place $(sum(compute_active_set_iterate(active_set)))"
                    @debug "difference iterates\n$(norm(new_iterate_real - new_iterate_theo))"
                    error("END")
                end
            end
        end
        dual_gap = 2phi
        if trajectory
            push!(
                traj_data,
                (
                    t,
                    primal,
                    primal - dual_gap,
                    dual_gap,
                    (time_ns() - time_start) / 1.0e9,
                    length(active_set),
                ),
            )
        end
        t = t + 1
        if verbose && mod(t, print_iter) == 0
            rep = (
                tt,
                string(t),
                primal,
                primal - dual_gap,
                dual_gap,
                (time_ns() - time_start) / 1.0e9,
                length(active_set),
                non_simplex_iter,
                nforced_fw,
            )
            print_iter_func(rep)
            flush(stdout)
        end
    end
    if verbose
        x = compute_active_set_iterate(active_set)
        grad!(gradient, x)
        v = compute_extreme_point(lmo, gradient)
        primal = f(x)
        dual_gap = 2phi
        rep = (
            last,
            string(t - 1),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
            nforced_fw,
        )
        print_iter_func(rep)
        flush(stdout)
    end
    active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
    active_set_renormalize!(active_set)
    x = compute_active_set_iterate(active_set)
    grad!(gradient, x)
    v = compute_extreme_point(lmo, gradient)
    primal = f(x)
    dual_gap = 2phi
    if verbose
        rep = (
            pp,
            string(t - 1),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
            nforced_fw,
        )
        print_iter_func(rep)
        print_footer()
        flush(stdout)
    end
    return x, v, primal, dual_gap, traj_data
end


"""
    update_simplex_gradient_descent!(active_set::ActiveSet, direction, f)

Performs a Simplex Gradient Descent step and modifies `active_set` inplace.

Returns boolean flag -> whether next step must be a FW step (if numerical instability).

Algorithm reference and notation taken from:
Blended Conditional Gradients:The Unconditioning of Conditional Gradients
https://arxiv.org/abs/1805.07311
"""
function update_simplex_gradient_descent!(
    active_set::ActiveSet,
    direction,
    f;
    L=nothing,
    linesearch_tol=10e-10,
    step_lim=100,
    weight_purge_threshold=1e-12,
)
    c = [dot(direction, a) for a in active_set.atoms]
    k = length(active_set)
    csum = sum(c)
    c .-= (csum / k)
    # name change to stay consistent with the paper, c is actually updated in-place
    d = c
    if norm(d) <= 1e-8
        @info "Resetting active set."
        # resetting active set to singleton
        a0 = active_set.atoms[1]
        empty!(active_set)
        push!(active_set, (1, a0))
        return false
    end
    η = eltype(d)(Inf)
    # NOTE: sometimes the direction is non-improving
    # usual suspects are floating-point errors when multiplying atoms with near-zero weights
    # in that case, inverting the sense of d
    @inbounds if dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), direction) < 0
        @warn "Non-improving d, aborting simplex descent"
        println(dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), direction))
        return true
    end
    rem_idx = -1
    @inbounds for idx in eachindex(d)
        if d[idx] ≥ 0
            max_val = active_set.weights[idx] / d[idx]
            if η > max_val
                η = max_val
                rem_idx = idx
            end
        end
    end
    # TODO at some point avoid materializing both x and y
    η = max(0, η)
    x = compute_active_set_iterate(active_set)
    @. active_set.weights -= η * d
    active_set.weights[rem_idx] = 0
    active_set_renormalize!(active_set)
    y = compute_active_set_iterate(active_set)
    if f(x) ≥ f(y)
        active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
        return false
    end
    linesearch_method = L === nothing || !isfinite(L) ? backtracking : shortstep
    if linesearch_method == backtracking
        _, gamma =
            backtrackingLS(f, direction, x, y, linesearch_tol=linesearch_tol, step_lim=step_lim)
    else # == shortstep, just two methods here for now
        gamma = dot(direction, x - y) / (L * norm(x - y)^2)
    end
    # step back from y to x by (1 - γ) η d
    # new point is x - γ η d
    @. active_set.weights += η * (1 - gamma) * d
    active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
    return false
end

"""
Returns either a tuple `(y, val)` with `y` an atom from the active set satisfying
the progress criterion and `val` the corresponding gap `dot(y, direction)`
or the same tuple with `y` from the LMO.

`inplace_loop` controls whether the iterate type allows in-place writes.
`kwargs` are passed on to the LMO oracle.
"""
function lp_separation_oracle(
    lmo::LinearMinimizationOracle,
    active_set::ActiveSet,
    direction,
    min_gap,
    Ktolerance;
    inplace_loop=true,
    force_fw_step::Bool=false,
    kwargs...,
)
    # if FW step forced, ignore active set
    if !force_fw_step
        ybest = active_set.atoms[1]
        x = active_set.weights[1] * active_set.atoms[1]
        if inplace_loop
            if !isa(x, Union{Array, SparseArrays.AbstractSparseArray})
                x = convert(SparseVector{eltype(x)}, x)
            end
        end
        val_best = dot(direction, ybest)
        for idx in 2:length(active_set)
            y = active_set.atoms[idx]
            if inplace_loop
                x .+= active_set.weights[idx] * y
            else
                x += active_set.weights[idx] * y
            end
            val = dot(direction, y)
            if val < val_best
                val_best = val
                ybest = y
            end
        end
        xval = dot(direction, x)
        if xval - val_best ≥ min_gap / Ktolerance
            return (ybest, val_best)
        end
    end
    # otherwise, call the LMO
    y = compute_extreme_point(lmo, direction; kwargs...)
    # don't return nothing but y, dot(direction, y) / use y for step outside / and update phi as in LCG (lines 402 - 406)
    return (y, dot(direction, y))
end
