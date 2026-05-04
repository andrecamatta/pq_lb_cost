# Quando a alocação marginal diverge da pro-rata
#
# O custo linear por funding gap faz a alocacao pro-rata e a marginal ficarem
# muito parecidas. Este exemplo adiciona um premio endogeno de crowding:
# se LB(0) passa de certo percentual do funding, o spread marginal sobe.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

bank = multi_liabilities_setup(K = 1000.0, x_pct = 0.18)
threshold = 0.20
slope = 0.12

linear = allocate_cost_by_liability(bank)
endogenous = marginal_endogenous_cost_by_liability(
    bank;
    threshold_ratio = threshold,
    crowding_slope = slope,
)

println("Alocacao com spread endogeno de liquidez")
println("="^72)
@printf "LB(0) = %.2f, funding total = %.2f, LB/funding = %.2f%%\n" lb_initial(bank) total_funding(bank) 100lb_initial(bank) / total_funding(bank)
@printf "Threshold = %.0f%%, crowding_slope = %.1f%%\n\n" 100threshold 100slope

@printf "%-25s %-15s %-15s %-15s\n" "Passivo" "Pro-rata" "Marginal endog." "Diferenca"
println("-"^72)
for liab in bank.liabilities
    p = linear[liab.name]
    m = endogenous[liab.name]
    @printf "%-25s %-15.4f %-15.4f %-15.4f\n" liab.name p m (m - p)
end

println("\nCusto linear total: ", round(sum(values(linear)), digits = 4))
println("Custo endogeno total: ", round(sum(values(endogenous)), digits = 4))
