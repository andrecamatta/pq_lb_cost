# Runoff diferenciado por passivo
#
# Mostra uma configuração mais próxima de FTP: cada fonte de funding tem seu
# próprio x%, em vez de aplicar o mesmo estresse de rollover a todo o balanço.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

bank = differentiated_runoff_setup(K = 1000.0)

println("Runoff diferenciado por passivo")
println("="^84)
@printf "%-22s %-8s %-10s %-10s %-10s %-12s\n" "Passivo" "Prazo" "Notional" "sB(bps)" "x%" "Custo"
println("-"^84)

allocation = allocate_cost_by_liability(bank)
for liab in bank.liabilities
    @printf "%-22s %-8d %-10.2f %-10.0f %-10.1f %-12.4f\n" liab.name liab.maturity_periods liab.notional 10000liab.funding_spread 100rollover_failure(liab, bank) allocation[liab.name]
end

println("-"^84)
@printf "%-22s %-8s %-10.2f %-10s %-10s %-12.4f\n" "Total" "" total_funding(bank) "" "" sum(values(allocation))
@printf "\nLB(0) = %.2f (%.2f%% do funding total)\n" lb_initial(bank) 100lb_initial(bank) / total_funding(bank)
