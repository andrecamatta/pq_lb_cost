# Otimização de mix de funding
#
# Compara duas funções objetivo:
# 1. minimizar apenas o custo direto de funding;
# 2. minimizar custo direto de funding + custo em valor presente do buffer.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQLBCost
using Printf

sources = [
    FundingSource(
        name = "Depósito varejo",
        maturity_periods = 1,
        funding_spread = 0.0045,
        rollover_failure = 0.05,
        min_weight = 0.20,
        max_weight = 0.70,
    ),
    FundingSource(
        name = "CDB atacado",
        maturity_periods = 1,
        funding_spread = 0.0042,
        rollover_failure = 0.30,
        min_weight = 0.00,
        max_weight = 0.60,
    ),
    FundingSource(
        name = "LF 2y",
        maturity_periods = 2,
        funding_spread = 0.012,
        rollover_failure = 0.10,
        min_weight = 0.10,
        max_weight = 0.50,
    ),
    FundingSource(
        name = "Senior 3y",
        maturity_periods = 3,
        funding_spread = 0.020,
        rollover_failure = 0.08,
        min_weight = 0.10,
        max_weight = 0.40,
    ),
]

without_buffer = optimize_funding_mix(
    sources;
    total_funding = 1000.0,
    asset_maturity = 6,
    risk_free_rate = 0.03,
    include_buffer_cost = false,
    name = "Sem custo do buffer",
)

with_buffer = optimize_funding_mix(
    sources;
    total_funding = 1000.0,
    asset_maturity = 6,
    risk_free_rate = 0.03,
    include_buffer_cost = true,
    name = "Com custo do buffer",
)

function weight(result, source_name)
    total = total_funding(result.bank)
    liab = findfirst(l -> l.name == source_name, result.bank.liabilities)
    return liab === nothing ? 0.0 : result.bank.liabilities[liab].notional / total
end

println("Otimização de mix de funding")
println("="^104)
@printf "%-20s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s\n" "Objetivo" "Depósito" "CDB atac." "LF 2y" "Senior 3y" "C funding" "C buffer" "C econômico" "LB(0)"
println("-"^104)

for result in (without_buffer, with_buffer)
    economic_total = result.direct_funding_cost + result.buffer_cost
    @printf "%-20s %-11.0f %-11.0f %-11.0f %-11.0f %-11.2f %-11.2f %-11.2f %-11.2f\n" result.bank.name 100weight(result, "Depósito varejo") 100weight(result, "CDB atacado") 100weight(result, "LF 2y") 100weight(result, "Senior 3y") result.direct_funding_cost result.buffer_cost economic_total lb_initial(result.bank)
end

println("-"^104)
println("Custos unitários por 1 unidade de funding")
@printf "%-16s %-13s %-13s %-13s %-13s\n" "Fonte" "C funding" "C buffer" "C total" "x%"
for source in sources
    direct = with_buffer.unit_direct_costs[source.name]
    buffer = with_buffer.unit_buffer_costs[source.name]
    @printf "%-16s %-13.5f %-13.5f %-13.5f %-13.1f\n" source.name direct buffer direct + buffer 100source.rollover_failure
end
