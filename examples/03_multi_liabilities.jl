# Exemplo 3 — Vários passivos financiando o mesmo ativo (§7.4)
#
# Quando múltiplos passivos com prazos e spreads diferentes financiam um
# mesmo ativo, o perfil LB(t) deixa de ser monotônico, e a alocação do
# custo entre passivos requer abordagem marginal (não pro-rata simples).

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

bank = multi_liabilities_setup(K = 1000.0, x_pct = 0.10)
summary_lb_cost(bank)

println("\nComparação de alocações:")
println("-"^72)
prorata = allocate_cost_by_liability(bank)
marginal = marginal_cost_by_liability(bank)

@printf "%-25s %-15s %-15s %-15s\n" "Passivo" "Pro-rata" "Marginal" "Diferença"
println("-"^72)
for liab in bank.liabilities
    p = prorata[liab.name]
    m = marginal[liab.name]
    @printf "%-25s %-15.4f %-15.4f %-15.4f\n" liab.name p m (m - p)
end

println("\nA alocação marginal capta a interação entre passivos:")
println("passivos curtos geram mais rollovers e são penalizados relativamente.")
