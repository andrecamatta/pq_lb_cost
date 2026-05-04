# Superfície de sensibilidade custo vs x% e sB
#
# Gera uma grade simples que ajuda o leitor a enxergar duas alavancas:
# o estresse de rollover aumenta o tamanho do LB, e o funding spread aumenta
# o custo de carregar esse estoque.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

K = 1000.0
x_grid = [0.05, 0.10, 0.15, 0.20, 0.30]
spread_grid_bps = [25, 50, 100, 200, 400]

outdir = normpath(joinpath(@__DIR__, "..", "outputs"))
mkpath(outdir)
outfile = joinpath(outdir, "cost_surface.csv")

open(outfile, "w") do io
    println(io, "x_pct,sB_bps,lb_initial,cost,cost_pct_asset")
    for x in x_grid, s_bps in spread_grid_bps
        bank = canonical_setup(K = K, x_pct = x, sB = s_bps / 10_000.0)
        cost = lb_cost_with_spread(bank)
        println(io, join((
            x,
            s_bps,
            lb_initial(bank),
            cost,
            cost / K,
        ), ","))
    end
end

println("Superficie custo vs x% e sB")
println("="^72)
@printf "%-8s %-10s %-12s %-12s %-12s\n" "x%" "sB(bps)" "LB(0)" "Custo" "Custo/K"
println("-"^72)
for x in x_grid, s_bps in spread_grid_bps
    bank = canonical_setup(K = K, x_pct = x, sB = s_bps / 10_000.0)
    cost = lb_cost_with_spread(bank)
    @printf "%-8.0f %-10d %-12.2f %-12.4f %.2f%%\n" 100x s_bps lb_initial(bank) cost 100cost / K
end

println("\nCSV salvo em: $outfile")
