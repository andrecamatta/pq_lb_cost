# Exemplo 2 — Comparação entre economia sem default e economia com default
#
# Reproduz o trade-off central do §7.3:
# - Sem default: P&L do LB = 0 (Prop 7.3.3)
# - Com default e sB > 0: custo incremental positivo para carregar o LB
#   O custo abaixo nao e o custo total de funding do ativo.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

println("Comparação: economia sem default vs com default")
println("="^72)

K = 1000.0
x = 0.10
spreads_bps = [0, 25, 50, 100, 200, 400]

@printf "%-15s %-15s %-15s\n" "sB (bps)" "LB(0)" "Custo do LB"
println("-"^45)
for s_bps in spreads_bps
    bank = canonical_setup(K = K, x_pct = x, sB = s_bps / 10_000.0)
    @printf "%-15d %-15.2f %-15.4f\n" s_bps lb_initial(bank) lb_cost_with_spread(bank)
end

println("\nNote como o custo escala linearmente com sB (Prop. 7.3.6).")
println("Para sB = 0, o custo é zero (Prop. 7.3.3).")
