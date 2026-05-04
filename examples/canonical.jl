# Caso canônico de Castagna e Fede (2013, §7.3)
#
# Banco com ativo de 3 períodos (T_A = 3) financiado por um único passivo
# de 1 período (T_L = 1). Cenário de estresse de rollover: 10% do passivo
# falha em ser renovado em cada data de rollover.
#
# Prediz: LB(0) = K · (1 - (1-x%)^2) = 100 · 0.19 = 19.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost

bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
summary_lb_cost(bank)

println("\nVerificação numérica de Prop. 7.3.3:")
bank_riskfree = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.0)
println("  P&L do LB em economia sem default = ", lb_cost_riskfree(bank_riskfree))
