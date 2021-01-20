import FrankWolfe
import LinearAlgebra


n = Int(1e2)
k = 10000

xpi = rand(n);
total = sum(xpi);
const xp = xpi ./ total;

f(x) = LinearAlgebra.norm(x-xp)^2
grad(x) = 2 * (x-xp)

# better for memory consumption as we do coordinate-wise ops

function cf(x,xp)
    return @. LinearAlgebra.norm(x-xp)^2
end

function cgrad(x,xp)
    return @. 2 * (x-xp)
end

# lmo = FrankWolfe.KSparseLMO(100, 1.0)
# lmo = FrankWolfe.LpNormLMO{Float64, 1}(1.0)
# lmo = FrankWolfe.ProbabilitySimplexOracle(1.0);
lmo = FrankWolfe.UnitSimplexOracle(1.0);
x0 = FrankWolfe.compute_extreme_point(lmo, rand(n))
# print(x0)

FrankWolfe.benchmark_oracles(x -> cf(x,xp),x -> cgrad(x,xp),lmo,n;k=100,T=Float64)

# 1/t *can be* better than short step

println("\n==> Short Step rule - if you know L.\n")

@time x, v, primal, dualGap, trajectorySs = FrankWolfe.fw(f,grad,lmo,x0,maxIt=k,
    stepSize=FrankWolfe.shortstep,L=2,printIt=k/10,emph=FrankWolfe.memory,verbose=true, trajectory=true);

println("\n==> Short Step rule with momentum - if you know L.\n")

@time x, v, primal, dualGap, trajectoryM = FrankWolfe.fw(f,grad,lmo,x0,maxIt=k,
    stepSize=FrankWolfe.shortstep,L=2,printIt=k/10,emph=FrankWolfe.blas,verbose=true, trajectory=true, momentum=0.9);
    
println("\n==> Adaptive if you do not know L.\n")

@time x, v, primal, dualGap, trajectoryAda = FrankWolfe.fw(f,grad,lmo,x0,maxIt=k,
    stepSize=FrankWolfe.adaptive,L=100,printIt=k/10,emph=FrankWolfe.memory,verbose=true, trajectory=true);

# println("\n==> Goldenratio LS.\n")

# @time x, v, primal, dualGap, trajectoryGr = FrankWolfe.fw(f,grad,lmo,x0,maxIt=k,
#     stepSize=FrankWolfe.goldenratio,L=100,printIt=k/10,emph=FrankWolfe.memory,verbose=true, trajectory=true);

# println("\n==> Backtracking LS.\n")

# @time x, v, primal, dualGap, trajectoryBack = FrankWolfe.fw(f,grad,lmo,x0,maxIt=k,
#     stepSize=FrankWolfe.backtracking,L=100,printIt=k/10,emph=FrankWolfe.memory,verbose=true, trajectory=true);
    
    
println("\n==> Agnostic if function is too expensive for adaptive.\n")

@time x, v, primal, dualGap, trajectoryAg = FrankWolfe.fw(f,grad,lmo,x0,maxIt=k,
    stepSize=FrankWolfe.agnostic,printIt=k/10,emph=FrankWolfe.memory,verbose=true, trajectory=true);



data = [trajectorySs, trajectoryAda, trajectoryAg, trajectoryM] 
label = ["short step" "adaptive" "agnostic" "momentum"]


FrankWolfe.plot_trajectories(data,label)
