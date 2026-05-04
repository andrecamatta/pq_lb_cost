# Cenário de estresse pior que o previsto (§7.5)
#
# O LB foi dimensionado supondo x% = 10%. O que acontece se o estresse real
# subir para 20%? Qual é o tamanho do shortfall e em que data ocorreria o
# breach do buffer pré-construído?

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

# Banco dimensionado com x% = 10%
bank = canonical_setup(K = 1000.0, x_pct = 0.10, sB = 0.01)
println("Banco dimensionado com x_planejado = 10%")
@printf "LB(0) construído ex-ante: %.2f\n\n" lb_initial(bank)

# Vamos testar cenários de estresse real maiores que o previsto
println("Sensibilidade ao estresse real:")
println("-"^72)
@printf "%-15s %-15s %-15s %-15s\n" "x_real" "Gap real" "Shortfall" "Breach?"
println("-"^72)
for x_real in [0.05, 0.10, 0.15, 0.20, 0.30]
    r = cost_under_severer_scenario(bank, x_real)
    breach_str = r.breach ? "SIM" : "não"
    @printf "%-15.0f%% %-15.2f %-15.2f %-15s\n" 100*x_real r.realized_gap r.shortfall breach_str
end

println("\nHorizonte de breach sob estresse de 30%:")
horizon = breach_horizon(bank, 0.30)
if horizon === nothing
    println("  LB cobre todo o horizonte")
else
    println("  Breach ocorreria no período t = $horizon")
end

println("\nLição §7.5: o trade-off entre custo ex-ante e probabilidade de breach")
println("é fundamental. Dimensionar o LB para o pior caso elimina breach mas eleva")
println("o custo de carrego linearmente em x%.")
