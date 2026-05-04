"""
    direct_funding_spread_cost(bank)

Valor presente do spread direto de funding pago sobre os saldos contratados ou
projetados dos passivos. O runoff de estresse não reduz este termo; ele entra
separadamente no custo do buffer de liquidez.
"""
function direct_funding_spread_cost(bank::StressBank)
    total = 0.0
    for liab in bank.liabilities
        total += _direct_funding_spread_cost(
            liab,
            bank.risk_free_rate,
            bank.asset_maturity,
        )
    end
    return total
end

function _direct_funding_spread_cost(
    liab::Liability,
    rf::Float64,
    asset_maturity::Int,
)
    previous_t = 0
    cost = 0.0
    for t in liab.maturity_periods:liab.maturity_periods:asset_maturity
        dt = t - previous_t
        discount = 1.0 / (1 + rf)^t
        cost += liab.notional * liab.funding_spread * dt * discount
        previous_t = t
    end
    if previous_t < asset_maturity
        t = asset_maturity
        dt = t - previous_t
        discount = 1.0 / (1 + rf)^t
        cost += liab.notional * liab.funding_spread * dt * discount
    end
    return cost
end

"""
    optimize_funding_mix(sources; total_funding, asset_maturity, risk_free_rate,
                         include_buffer_cost)

Resolve o problema linear de mix de funding com limites mínimos e máximos por
fonte. A função objetivo minimiza o custo direto de funding; quando
`include_buffer_cost=true`, adiciona o custo em valor presente do buffer de
liquidez gerado por cada fonte.

Como os spreads e os runoffs são exógenos nesta especificação, o custo unitário
de cada fonte é constante e o problema é linear. A implementação usa JuMP com
HiGHS.
"""
function optimize_funding_mix(
    sources::Vector{FundingSource};
    total_funding::Float64 = 1000.0,
    asset_maturity::Int = 6,
    risk_free_rate::Float64 = 0.03,
    include_buffer_cost::Bool = true,
    name::String = include_buffer_cost ? "Mix ótimo com custo do buffer" : "Mix ótimo sem custo do buffer",
)
    isempty(sources) && throw(ArgumentError("sources não pode ser vazio"))
    min_sum = sum(s.min_weight for s in sources)
    max_sum = sum(s.max_weight for s in sources)
    min_sum <= 1.0 + 1e-12 || throw(ArgumentError("soma dos pesos mínimos excede 100%"))
    max_sum >= 1.0 - 1e-12 || throw(ArgumentError("soma dos pesos máximos é inferior a 100%"))

    unit_direct = Dict{String, Float64}()
    unit_buffer = Dict{String, Float64}()
    unit_total = Dict{String, Float64}()
    for source in sources
        unit_liab = Liability(
            name = source.name,
            notional = 1.0,
            maturity_periods = source.maturity_periods,
            funding_spread = source.funding_spread,
            rollover_failure = source.rollover_failure,
        )
        unit_bank = StressBank(
            name = source.name,
            asset_notional = 1.0,
            asset_maturity = asset_maturity,
            liabilities = [unit_liab],
            risk_free_rate = risk_free_rate,
        )
        unit_direct[source.name] = direct_funding_spread_cost(unit_bank)
        unit_buffer[source.name] = lb_cost_with_spread(unit_bank)
        unit_total[source.name] = unit_direct[source.name] +
                                  (include_buffer_cost ? unit_buffer[source.name] : 0.0)
    end

    model = Model(HiGHS.Optimizer)
    set_silent(model)
    source_names = [source.name for source in sources]
    @variable(model, weights[source_names] >= 0)
    for source in sources
        set_lower_bound(weights[source.name], source.min_weight)
        set_upper_bound(weights[source.name], source.max_weight)
    end
    @constraint(model, sum(weights[name] for name in source_names) == 1.0)
    @objective(model, Min, total_funding * sum(unit_total[name] * weights[name] for name in source_names))
    optimize!(model)
    is_solved_and_feasible(model) || error("otimização de mix de funding não encontrou solução viável")

    optimal_weights = Dict(name => value(weights[name]) for name in source_names)

    liabilities = Liability[]
    for source in sources
        notional = total_funding * optimal_weights[source.name]
        if notional > 1e-8
            push!(liabilities, Liability(
                name = source.name,
                notional = notional,
                maturity_periods = source.maturity_periods,
                funding_spread = source.funding_spread,
                rollover_failure = source.rollover_failure,
            ))
        end
    end
    bank = StressBank(
        name = name,
        asset_notional = total_funding,
        asset_maturity = asset_maturity,
        liabilities = liabilities,
        risk_free_rate = risk_free_rate,
    )
    direct = direct_funding_spread_cost(bank)
    buffer = lb_cost_with_spread(bank)
    total = direct + (include_buffer_cost ? buffer : 0.0)
    economic_total = direct + buffer
    return FundingMixOptimizationResult(
        bank = bank,
        direct_funding_cost = direct,
        buffer_cost = buffer,
        total_cost = total,
        buffer_cost_share = economic_total == 0 ? 0.0 : buffer / economic_total,
        unit_direct_costs = unit_direct,
        unit_buffer_costs = unit_buffer,
        unit_total_costs = unit_total,
    )
end
