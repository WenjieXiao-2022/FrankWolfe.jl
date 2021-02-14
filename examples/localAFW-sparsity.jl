import FrankWolfe
using LinearAlgebra
using Random

n = Int(1e5)
k = 10000

s = rand(1:100)
@info "Seed $s"
Random.seed!(s)

xpi = rand(n);
total = sum(xpi);
const xp = xpi ./ total;

f(x) = norm(x - xp)^2
function grad!(storage, x)
    @. storage = 2 * (x - xp)
end

const lmo = FrankWolfe.KSparseLMO(100, 1.0)

# const lmo_big = FrankWolfe.KSparseLMO(100, big"1.0")
# const lmo = FrankWolfe.LpNormLMO{Float64,5}(1.0)
# lmo = FrankWolfe.ProbabilitySimplexOracle(1.0);
# lmo = FrankWolfe.UnitSimplexOracle(1.0);

# 5 lpnorm issue with zero gradient 
const x00 = FrankWolfe.compute_extreme_point(lmo, rand(n))

# const lmo = FrankWolfe.BirkhoffPolytopeLMO()
# cost = rand(n, n)
# const x00 = FrankWolfe.compute_extreme_point(lmo, cost)



FrankWolfe.benchmark_oracles(f, grad!, lmo, n; k=100, T=eltype(x00))

x0 = deepcopy(x00)
@time x, v, primal, dual_gap, trajectorySs = FrankWolfe.fw(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    line_search=FrankWolfe.shortstep,
    L=2,
    print_iter=k / 10,
    emphasis=FrankWolfe.memory,
    verbose=true,
    trajectory=true,
);

x0 = deepcopy(x00)
@time x, v, primal, dual_gap, trajectoryAda = FrankWolfe.afw(
f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    line_search=FrankWolfe.adaptive,
    L=100,
    print_iter=k / 10,
    emphasis=FrankWolfe.memory,
    verbose=true,
    trajectory=true,
);


println("\n==> Localized AFW.\n")

x0 = deepcopy(x00)
@time x, v, primal, dual_gap, trajectoryAdaLoc = FrankWolfe.afw(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    localized=true,
    localizedFactor=0.66, # 66,
    line_search=FrankWolfe.adaptive,
    L=100,
    print_iter=k / 10,
    emphasis=FrankWolfe.memory,
    verbose=true,
    trajectory=true,
);


x0 = deepcopy(x00)
@time x, v, primal, dual_gap, trajectoryAdaLoc5 = FrankWolfe.afw(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    localized=true,
    localizedFactor=0.5, # 66,
    line_search=FrankWolfe.adaptive,
    L=100,
    print_iter=k / 10,
    emphasis=FrankWolfe.memory,
    verbose=true,
    trajectory=true,
);

x0 = deepcopy(x00)
@time x, v, primal, dual_gap, trajectoryAdaLoc25 = FrankWolfe.afw(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    localized=true,
    localizedFactor=0.25, # 66,
    line_search=FrankWolfe.adaptive,
    L=100,
    print_iter=k / 10,
    emphasis=FrankWolfe.memory,
    verbose=true,
    trajectory=true,
);

x0 = deepcopy(x00)
@time x, v, primal, dual_gap, trajectoryAdaLoc1 = FrankWolfe.afw(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    localized=true,
    localizedFactor=0.1, # 66,
    line_search=FrankWolfe.adaptive,
    L=100,
    print_iter=k / 10,
    emphasis=FrankWolfe.memory,
    verbose=true,
    trajectory=true,
);


# data = [trajectorySs, trajectoryAda, trajectoryBCG]
# label = ["short step", "AFW", "BCG"]

data = [trajectorySs, trajectoryAda, trajectoryAdaLoc]
label = ["short step", "AFW", "AFW-Loc"]

# FrankWolfe.plot_trajectories(data, label, filename="convergence.pdf")

dataSparsity = [trajectoryAda, trajectoryAdaLoc, trajectoryAdaLoc5, trajectoryAdaLoc25, trajectoryAdaLoc1]
labelSparsity = ["AFW", "AFW-Loc066", "AFW-Loc05", "AFW-Loc025", "AFW-Loc01" ]

FrankWolfe.plot_sparsity(dataSparsity, labelSparsity,filename="sparse.pdf")