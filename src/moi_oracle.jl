
"""
    MathOptLMO{OT <: MOI.Optimizer} <: LinearMinimizationOracle

Linear minimization oracle with feasible space defined through a MathOptInterface.Optimizer.
The oracle call sets the direction and reruns the optimizer.

The `direction` vector has to be set in the same order of variables as the `MOI.ListOfVariableIndices()` getter.

The Boolean `use_modify` determines if the objective in`compute_extreme_point` is updated with
`MOI.modify(o, ::MOI.ObjectiveFunction, ::MOI.ScalarCoefficientChange)` or with `MOI.set(o, ::MOI.ObjectiveFunction, f)`.
`use_modify = true` decreases the runtime and memory allocation for models created as an optimizer object and defined directly
with MathOptInterface. `use_modify = false` should be used for CachingOptimizers.
"""
struct MathOptLMO{OT<:MOI.AbstractOptimizer} <: LinearMinimizationOracle
    o::OT
    use_modify::Bool
    function MathOptLMO(o, use_modify=true)
        MOI.set(o, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    
        #silent it
        MOI.set(o, MOI.Silent(), true)
        
        return new{typeof(o)}(o, use_modify)
    end
end

function compute_extreme_point(
    lmo::MathOptLMO{OT},
    direction::AbstractVector{T};
    kwargs...,
) where {OT,T<:Real}
    variables = MOI.get(lmo.o, MOI.ListOfVariableIndices())
    if lmo.use_modify
        for i in eachindex(variables)
            MOI.modify(
                lmo.o,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}(),
                MOI.ScalarCoefficientChange(variables[i], direction[i]),
            )
        end
    else
        terms = [MOI.ScalarAffineTerm(d, v) for (d, v) in zip(direction, variables)]
        obj = MOI.ScalarAffineFunction(terms, zero(T))
        MOI.set(lmo.o, MOI.ObjectiveFunction{typeof(obj)}(), obj)
    end
    return _optimize_and_return(lmo, variables)
end

function compute_extreme_point(
    lmo::MathOptLMO{OT},
    direction::AbstractMatrix{T};
    kwargs...,
) where {OT,T<:Real}
    n = size(direction, 1)
    v = compute_extreme_point(lmo, vec(direction))
    return reshape(v, n, n)
end


is_decomposition_invariant_oracle(::MathOptLMO) = true

function set_constraint(o, S, func, val, set, var_constraint_list::Dict)
    is_set = haskey(var_constraint_list, func)
    set_equal = false
    if S <: MOI.GreaterThan
        if set.lower ≈ val
            # VariableIndex LessThan-constraint is already set, needs to be deleted first
            if is_set
                c_idx = var_constraint_list[func]
                MOI.delete(o, c_idx)
            end
            MOI.add_constraint(o, func, MOI.EqualTo(set.lower))
            set_equal = true
        end
    elseif S <: MOI.LessThan
        if set.upper ≈ val
            # VariableIndex GreaterThan-constraint is already set, needs to be deleted first
            if is_set
                c_idx = var_constraint_list[func]
                MOI.delete(o, c_idx)
            end
            MOI.add_constraint(o, func, MOI.EqualTo(set.upper))
            set_equal = true
        end
    elseif S <: MOI.Interval
        if set.upper ≈ val || set.lower ≈ val
            set_equal = true
            if set.upper ≈ val
                MOI.add_constraint(o, func, MOI.EqualTo(set.upper))
            else
                MOI.add_constraint(o, func, MOI.EqualTo(set.lower))
            end
        end
    end
    if !set_equal 
        idx = MOI.add_constraint(o, func, set)
        var_constraint_list[func] = idx
    end     
end

function compute_inface_extreme_point(lmo::MathOptLMO{OT}, direction, x; kwargs...) where {OT}
    var_constraint_list = Dict([])
    lmo2 = copy(lmo)
    MOI.empty!(lmo2.o)
    MOI.set(lmo2.o, MOI.Silent(), true)
    variables = MOI.get(lmo.o, MOI.ListOfVariableIndices())
    MOI.add_variables(lmo2.o, length(variables)) 
    terms = [MOI.ScalarAffineTerm(d, v) for (d, v) in zip(direction, variables)]
    obj = MOI.ScalarAffineFunction(terms, zero(Float64))
    MOI.set(lmo2.o, MOI.ObjectiveFunction{typeof(obj)}(), obj)
    for (F, S) in MOI.get(lmo.o, MOI.ListOfConstraintTypesPresent())
        valvar(f) = x[f.value]
        const_list = MOI.get(lmo.o, MOI.ListOfConstraintIndices{F,S}())
        for c_idx in const_list
            if !(S <: MOI.ZeroOne)
                func = MOI.get(lmo.o, MOI.ConstraintFunction(), c_idx)
                val = MOIU.eval_variables(valvar, func)
                set = MOI.get(lmo.o, MOI.ConstraintSet(), c_idx)
                set_constraint(lmo2.o, S, func, val, set, var_constraint_list)
            end  
        end
    end
    MOI.set(lmo2.o, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(lmo2.o)
    a = MOI.get(lmo2.o, MOI.VariablePrimal(), variables)
    MOI.empty!(lmo2.o)
    return a
end

# Second version of compute_inface_extreme_point.
# Copy and modify the constriants if necesssary.
function compute_inface_extreme_point!(lmo::MathOptLMO{OT}, direction, x; kwargs...) where {OT}
    lmo2 = copy(lmo)
    MOI.set(lmo2.o, MOI.Silent(), true)
    variables = MOI.get(lmo2.o, MOI.ListOfVariableIndices())
    MOI.add_variables(lmo2.o, length(variables))
    terms = [MOI.ScalarAffineTerm(d, v) for (d, v) in zip(direction, variables)]
    obj = MOI.ScalarAffineFunction(terms, zero(Float64))
    MOI.set(lmo2.o, MOI.ObjectiveFunction{typeof(obj)}(), obj)
    for (F, S) in MOI.get(lmo2.o, MOI.ListOfConstraintTypesPresent())
        valvar(f) = x[f.value]
        const_list = MOI.get(lmo2.o, MOI.ListOfConstraintIndices{F,S}())
        for c_idx in const_list
            func = MOI.get(lmo2.o, MOI.ConstraintFunction(), c_idx)
            val = MOIU.eval_variables(valvar, func)
            set = MOI.get(lmo2.o, MOI.ConstraintSet(), c_idx)
            if S <: MOI.GreaterThan
                if set.lower ≈ val
                    MOI.delete(lmo2.o, c_idx)
                    func_dict = Dict(field => getfield(func, field) for field in fieldnames(typeof(func)))
                    
                    # Get the list of constraints with same ConstraintFunction but LessThan ConstraintSet.
                    const_list_less = MOI.get(lmo2.o, MOI.ListOfConstraintIndices{F,MOI.LessThan{Float64}}())
                    
                    # Check if the ConstraintFunction has other ConstraintSet.
                    # If exists, delete the constraint to avoid conflict.
                    for c_idx_less in const_list_less
                        func_less = MOI.get(lmo2.o, MOI.ConstraintFunction(), c_idx_less)
                        func_less_dict = Dict(field => getfield(func_less, field) for field in fieldnames(typeof(func_less)))
                        if func_less_dict == func_dict
                            MOI.delete(lmo2.o, c_idx_less)
                            break
                        end
                    end
                    MOI.add_constraint(lmo2.o, func, MOI.EqualTo(set.lower))
                end
            elseif S <: MOI.LessThan
                if set.upper ≈ val
                    MOI.delete(lmo2.o, c_idx)
                    func_dict = Dict(field => getfield(func, field) for field in fieldnames(typeof(func)))
                    const_list_greater = MOI.get(lmo2.o, MOI.ListOfConstraintIndices{F,MOI.GreaterThan{Float64}}())
                    for c_idx_greater in const_list_greater
                        func_greater = MOI.get(lmo2.o, MOI.ConstraintFunction(), c_idx_greater)
                        func_greater_dict = Dict(field => getfield(func_greater, field) for field in fieldnames(typeof(func_greater)))
                        if func_greater_dict == func_dict
                            MOI.delete(lmo2.o, c_idx_greater)
                            break
                        end
                    end
                    MOI.add_constraint(lmo2.o, func, MOI.EqualTo(set.upper))
                end
            elseif S <: MOI.Interval
                if set.upper ≈ val
                    MOI.delete(lmo2.o, c_idx)
                    MOI.add_constraint(lmo2.o, func, MOI.EqualTo(set.upper))
                elseif set.lower ≈ val
                    MOI.delete(lmo2.o, c_idx)
                    MOI.add_constraint(lmo2.o, func, MOI.EqualTo(set.lower))
                end
            end
        end
    end
    MOI.set(lmo2.o, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(lmo2.o)
    a = MOI.get(lmo2.o, MOI.VariablePrimal(), variables)
    MOI.empty!(lmo2.o)
    return a
end

function dicg_maximum_step(lmo::MathOptLMO{OT}, x, direction; exactness=1000, atol=1e-16) where {OT}
    gamma_max = 0.0
    gamma = 1.0
    precheck, on_lowerbound_idx_value,  on_upperbound_idx_value = is_constraints_feasible(lmo, x; atol)
    if !precheck
        error("x is not a fesible point!")
    end

    for (idx,value) in on_lowerbound_idx_value
        if direction[idx] > value
            return gamma_max
        end
    end

    for (idx,value) in on_upperbound_idx_value
        if direction[idx] < value
            return gamma_max
        end
    end

    while(exactness != 0)
        flag, _, on_lowerbound_idx_value = is_constraints_feasible(lmo, x-gamma*direction; atol)
        if flag
            if gamma === 1.0
                return gamma
            else
                gamma_max = max(gamma, gamma_max)
                gamma = (1+gamma_max) / 2
                exactness -= 1
            end
        end
        if !flag
            gamma = (gamma+gamma_max) / 2
            exactness -= 1
        end
    end
    return gamma_max
end

function is_constraints_feasible(lmo::MathOptLMO{OT}, x; atol=1e-7) where {OT}
    on_lowerbound_idx_value = []
    on_upperbound_idx_value =[]
    is_feasible = true
    for (F, S) in MOI.get(lmo.o, MOI.ListOfConstraintTypesPresent())
        valvar(f) = x[f.value]
        const_list = MOI.get(lmo.o, MOI.ListOfConstraintIndices{F,S}())
        done = false
        for c_idx in const_list
            if !(S <: MOI.ZeroOne)
                func = MOI.get(lmo.o, MOI.ConstraintFunction(), c_idx)
                val = MOIU.eval_variables(valvar, func)
                set = MOI.get(lmo.o, MOI.ConstraintSet(), c_idx)
                if ( S <: MOI.Interval)
                    if set.lower === val
                        push!(on_lowerbound_idx_value, (func.value, set.lower))
                    end
                    if set.upper === val
                        push!(on_upperbound_idx_value, (func.value, set.upper))
                    end
                end
                if ( S <: MOI.GreaterThan)
                    if set.lower === val
                        push!(on_lowerbound_idx_value, (func.value, set.lower))
                    end
                end
                if ( S <: MOI.LessThan)
                    if set.upper === val
                        push!(on_upperbound_idx_value, (func.value, set.upper))
                    end
                end
                # @debug("Constraint: $(F)-$(S) $(func) = $(val) in $(set)")
                dist = MOD.distance_to_set(MOD.DefaultDistance(), val, set)
                if dist > atol
                    is_feasible = false
                    done = true
                    break
                end
            end
        end
        if done
            break
        end
    end
    if is_feasible
        return [true, on_lowerbound_idx_value,on_upperbound_idx_value]
    else
        return [false, on_lowerbound_idx_value,on_upperbound_idx_value]
    end
end

function Base.copy(lmo::MathOptLMO{OT}; ensure_identity=true) where {OT}
    opt = OT() # creates the empty optimizer
    index_map = MOI.copy_to(opt, lmo.o)
    if ensure_identity
        for (src_idx, des_idx) in index_map.var_map
            if src_idx != des_idx
                error("Mapping of variables is not identity")
            end
        end
    end
    return MathOptLMO(opt)
end

function Base.copy(
    lmo::MathOptLMO{OT};
    ensure_identity=true,
) where {OTI,OT<:MOIU.CachingOptimizer{OTI}}
    opt = MOIU.CachingOptimizer(
        MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
        OTI(),
    )
    index_map = MOI.copy_to(opt, lmo.o)
    if ensure_identity
        for (src_idx, des_idx) in index_map.var_map
            if src_idx != des_idx
                error("Mapping of variables is not identity")
            end
        end
    end
    return MathOptLMO(opt)
end


function compute_extreme_point(
    lmo::MathOptLMO{OT},
    direction::AbstractVector{MOI.ScalarAffineTerm{T}};
    kwargs...,
) where {OT,T}
    if lmo.use_modify
        for d in direction
            MOI.modify(
                lmo.o,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}(),
                MOI.ScalarCoefficientChange(d.variable, d.coefficient),
            )
        end

        variables = MOI.get(lmo.o, MOI.ListOfVariableIndices())
        variables_to_zero = setdiff(variables, [dir.variable for dir in direction])

        terms = [
            MOI.ScalarAffineTerm(d, v) for
            (d, v) in zip(zeros(length(variables_to_zero)), variables_to_zero)
        ]

        for t in terms
            MOI.modify(
                lmo.o,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}(),
                MOI.ScalarCoefficientChange(t.variable, t.coefficient),
            )
        end
    else
        variables = [d.variable for d in direction]
        obj = MOI.ScalarAffineFunction(direction, zero(T))
        MOI.set(lmo.o, MOI.ObjectiveFunction{typeof(obj)}(), obj)
    end
    return _optimize_and_return(lmo, variables)
end

function _optimize_and_return(lmo, variables)
    MOI.optimize!(lmo.o)
    term_st = MOI.get(lmo.o, MOI.TerminationStatus())
    if term_st ∉ (MOI.OPTIMAL, MOI.ALMOST_OPTIMAL, MOI.SLOW_PROGRESS)
        @error "Unexpected termination: $term_st"
        return MOI.get.(lmo.o, MOI.VariablePrimal(), variables)
    end
    return MOI.get.(lmo.o, MOI.VariablePrimal(), variables)
end

"""
    convert_mathopt(lmo::LMO, optimizer::OT; kwargs...) -> MathOptLMO{OT}

Converts the given LMO to its equivalent MathOptInterface representation using `optimizer`.
Must be implemented by LMOs.
"""
function convert_mathopt end
