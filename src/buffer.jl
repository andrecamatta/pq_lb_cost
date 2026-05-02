"""
    available_funding(notional, x_pct, n_rollovers)

Calcula o funding disponível em data futura sob rollover stressado, a partir
da equação 7.1 de Castagna e Fede (2013):

    AVL(0, T) = K · (1 - x%)^N

Onde K é o nominal inicial, x% é a fração que falha em cada renovação, e N é
o número de rollovers até a data T.
"""
function available_funding(notional::Float64, x_pct::Float64, n_rollovers::Int)
    return notional * (1 - x_pct)^n_rollovers
end

"""
    funding_gap_schedule(liability, x_pct, asset_maturity)

Para um único passivo, retorna o vetor de funding gaps em cada data de rollover
dentro do horizonte do ativo. O passivo de prazo T_L tem N = floor(T_A / T_L) − 1
rollovers internos antes do vencimento do ativo.

Em cada data k = 1, 2, …, N, o gap é a fração que falha sobre o nominal que
sobrou da renovação anterior, descontada pela duração que ainda falta para o
ativo expirar.
"""
function funding_gap_schedule(
    liability::Liability,
    x_pct::Float64,
    asset_maturity::Int,
)
    T_L = liability.maturity_periods
    N = div(asset_maturity, T_L) - 1
    if N <= 0
        return Tuple{Int, Float64}[]
    end
    gaps = Tuple{Int, Float64}[]
    for k in 1:N
        # Em cada data de rollover, o gap é a fração x% sobre o que sobrou
        outstanding = liability.notional * (1 - x_pct)^(k - 1)
        gap = outstanding * x_pct
        push!(gaps, (k * T_L, gap))
    end
    return gaps
end

"""
    lb_initial(bank)

Tamanho do LB em t=0 que cobre integralmente os funding gaps em todas as
datas de rollover, em todos os passivos do banco.

LB(0) = Σ_j Σ_k FG_j(t_k) onde j indexa passivos e k indexa rollovers.

Em forma fechada para um único passivo:
    LB(0) = K · (1 - (1 - x%)^N)
"""
function lb_initial(bank::StressBank)
    total = 0.0
    for liab in bank.liabilities
        for (_, gap) in funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
            total += gap
        end
    end
    return total
end

"""
    lb_balance_path(bank)

Retorna a trajetória do saldo do LB ao longo do tempo: vetor de tuplas
(t, LB_t). Em t=0, LB começa no tamanho `lb_initial`. Em cada data de
rollover de cada passivo, o LB é decrementado pelo funding gap respectivo.
"""
function lb_balance_path(bank::StressBank)
    # Coleta todos os gaps em todas as datas
    events = Tuple{Int, Float64}[]
    for liab in bank.liabilities
        for (t, gap) in funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
            push!(events, (t, gap))
        end
    end
    sort!(events, by = first)

    # Constroi a trajetória
    lb_t = lb_initial(bank)
    path = Tuple{Int, Float64}[(0, lb_t)]
    for (t, gap) in events
        lb_t -= gap
        push!(path, (t, lb_t))
    end
    push!(path, (bank.asset_maturity, lb_t))
    return path
end

"""
    lb_cost_riskfree(bank)

Em economia sem default e LB investido em ativo risk-free, o P&L do LB é
zero (Proposition 7.3.3 de Castagna e Fede). A função retorna o P&L
calculado período-a-período para verificação numérica.

Para cada passivo, em cada período em que parte do LB está alocada, o LB
rende r_f e o passivo correspondente custa r_f. O P&L total é zero.
"""
function lb_cost_riskfree(bank::StressBank)
    rf = bank.risk_free_rate
    cost = 0.0
    for liab in bank.liabilities
        gaps = funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
        for (t_gap, gap) in gaps
            # Custo = juros pagos ao passivo do LB durante t_gap períodos
            interest_paid = gap * rf * t_gap
            # Retorno = juros recebidos do investimento do LB em ativo risk-free
            interest_earned = gap * rf * t_gap
            cost += interest_paid - interest_earned
        end
    end
    return cost
end

"""
    lb_cost_with_spread(bank)

Em economia com default e o banco pagando funding spread sB sobre risk-free,
o LB tem custo positivo, equivalente ao custo do funding extra que sustenta o
buffer ao longo de cada janela de rollover.

Fórmula geral (versão simplificada do §7.3.4 com sB constante por passivo):

    LBC(0) ≈ Σ_j Σ_k D(0,t_k) · sB_j · gap_jk · t_k

Onde D(0,t) é o fator de desconto risk-free e t_k é o tempo durante o qual o
gap precisa estar coberto.

Esta função usa desconto contínuo aproximado e assume sB constante para cada
passivo. Para sB com term structure, usar `lb_cost_general`.
"""
function lb_cost_with_spread(bank::StressBank)
    rf = bank.risk_free_rate
    cost = 0.0
    for liab in bank.liabilities
        gaps = funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
        for (t_gap, gap) in gaps
            # O LB de tamanho `gap` é mantido entre t=0 e t=t_gap
            # Custo de carrego = sB pago sobre o gap durante t_gap períodos, descontado a r_f
            discount = 1.0 / (1 + rf)^t_gap
            carry_cost = gap * liab.funding_spread * t_gap * discount
            cost += carry_cost
        end
    end
    return cost
end

"""
    lb_cost_general(bank, sB_curve)

Versão geral do custo do LB com term structure de funding spread. `sB_curve`
é uma função `t -> sB(t)` que retorna o spread aplicável em cada período.

LBC(0) = Σ_j Σ_k D(0,t_k) · sB(t_k) · gap_jk · t_k
"""
function lb_cost_general(bank::StressBank, sB_curve::Function)
    rf = bank.risk_free_rate
    cost = 0.0
    for liab in bank.liabilities
        gaps = funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
        for (t_gap, gap) in gaps
            discount = 1.0 / (1 + rf)^t_gap
            carry_cost = gap * sB_curve(t_gap) * t_gap * discount
            cost += carry_cost
        end
    end
    return cost
end

"""
    allocate_cost_by_liability(bank)

Aloca o custo total do LB por passivo, na proporção da contribuição
individual de cada um para os funding gaps. Esta é a alocação pro-rata
baseada em uso. Para alocação marginal (mais sofisticada), ver
`marginal_cost_by_liability`.
"""
function allocate_cost_by_liability(bank::StressBank)
    rf = bank.risk_free_rate
    allocation = Dict{String, Float64}()
    for liab in bank.liabilities
        gaps = funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
        liab_cost = 0.0
        for (t_gap, gap) in gaps
            discount = 1.0 / (1 + rf)^t_gap
            liab_cost += gap * liab.funding_spread * t_gap * discount
        end
        allocation[liab.name] = liab_cost
    end
    return allocation
end

"""
    marginal_cost_by_liability(bank)

Aloca o custo do LB por passivo usando o método marginal: para cada passivo,
calcula o custo total do LB com e sem aquele passivo, e atribui a diferença
ao passivo. Esta é a alocação consistente com o princípio Aumann-Shapley
quando os passivos interagem.

Em geral, a soma das alocações marginais não iguala o custo total do LB
(efeito de interação); a função normaliza para garantir que a soma bata
com o custo total.
"""
function marginal_cost_by_liability(bank::StressBank)
    total_cost = lb_cost_with_spread(bank)
    marginal = Dict{String, Float64}()
    for (i, liab) in enumerate(bank.liabilities)
        # Banco sem este passivo
        other_liabs = [l for (j, l) in enumerate(bank.liabilities) if j != i]
        if isempty(other_liabs)
            marginal[liab.name] = total_cost
            continue
        end
        bank_without = StressBank(
            name = bank.name,
            asset_notional = bank.asset_notional,
            asset_maturity = bank.asset_maturity,
            asset_credit_spread = bank.asset_credit_spread,
            liabilities = other_liabs,
            risk_free_rate = bank.risk_free_rate,
            stress_rollover_failure = bank.stress_rollover_failure,
        )
        cost_without = lb_cost_with_spread(bank_without)
        marginal[liab.name] = total_cost - cost_without
    end
    # Normaliza para somar ao total
    total_marginal = sum(values(marginal))
    if total_marginal > 0
        for k in keys(marginal)
            marginal[k] *= total_cost / total_marginal
        end
    end
    return marginal
end

"""
    lb_cost_with_endogenous_spread(bank; threshold_ratio, crowding_slope)

Calcula o custo do LB quando o spread de captação incorpora um prêmio
endógeno de crowding. A intuição é que buffers pequenos podem ser financiados
ao spread observado de cada passivo, mas buffers grandes consomem capacidade
de captação do banco e elevam o spread marginal de toda a operação.

Este é o custo incremental de carregar o buffer, não o custo total de funding
do balanço. O funding dos ativos existe mesmo sem LB; aqui medimos apenas o
spread aplicado ao estoque líquido pré-posicionado para cobrir gaps.

O prêmio adicional é ativado quando `LB(0) / total_funding` excede
`threshold_ratio`:

    s_extra = crowding_slope * max(LB(0) / funding - threshold_ratio, 0)

Com `crowding_slope = 0`, a função coincide com `lb_cost_with_spread`.
"""
function lb_cost_with_endogenous_spread(
    bank::StressBank;
    threshold_ratio::Float64 = 0.20,
    crowding_slope::Float64 = 0.10,
)
    return _lb_cost_with_endogenous_spread(
        bank;
        threshold_ratio = threshold_ratio,
        crowding_slope = crowding_slope,
        capacity_funding = total_funding(bank),
    )
end

function _lb_cost_with_endogenous_spread(
    bank::StressBank;
    threshold_ratio::Float64,
    crowding_slope::Float64,
    capacity_funding::Float64,
)
    rf = bank.risk_free_rate
    funding = capacity_funding
    lb_ratio = funding > 0 ? lb_initial(bank) / funding : 0.0
    extra_spread = crowding_slope * max(lb_ratio - threshold_ratio, 0.0)

    cost = 0.0
    for liab in bank.liabilities
        gaps = funding_gap_schedule(liab, bank.stress_rollover_failure, bank.asset_maturity)
        effective_spread = liab.funding_spread + extra_spread
        for (t_gap, gap) in gaps
            discount = 1.0 / (1 + rf)^t_gap
            cost += gap * effective_spread * t_gap * discount
        end
    end
    return cost
end

"""
    marginal_endogenous_cost_by_liability(bank; threshold_ratio, crowding_slope)

Aloca o custo com spread endógeno por valor de Shapley exato. Como o prêmio
de crowding depende do LB total, adicionar um passivo altera o spread marginal
dos demais. Por isso a alocação resultante pode divergir da alocação pro-rata
mesmo quando os funding gaps são aditivos.

Como o cálculo exato enumera permutações, a função é destinada a exemplos
pequenos. Para mais de 8 passivos, agregue os passivos por bucket antes.
"""
function marginal_endogenous_cost_by_liability(
    bank::StressBank;
    threshold_ratio::Float64 = 0.20,
    crowding_slope::Float64 = 0.10,
)
    n = length(bank.liabilities)
    allocation = Dict(liab.name => 0.0 for liab in bank.liabilities)
    n == 0 && return allocation
    n > 8 && error("Shapley exato enumera n! permutações; agregue passivos por bucket para n > 8.")

    capacity_funding = total_funding(bank)
    orders = _index_permutations(collect(1:n))
    for order in orders
        coalition = Int[]
        previous_cost = 0.0
        for idx in order
            push!(coalition, idx)
            coalition_bank = _bank_with_liability_indices(bank, coalition)
            new_cost = _lb_cost_with_endogenous_spread(
                coalition_bank;
                threshold_ratio = threshold_ratio,
                crowding_slope = crowding_slope,
                capacity_funding = capacity_funding,
            )
            allocation[bank.liabilities[idx].name] += new_cost - previous_cost
            previous_cost = new_cost
        end
    end

    for k in keys(allocation)
        allocation[k] /= length(orders)
    end
    return allocation
end

function _bank_with_liability_indices(bank::StressBank, indices::Vector{Int})
    return StressBank(
        name = bank.name,
        asset_notional = bank.asset_notional,
        asset_maturity = bank.asset_maturity,
        asset_credit_spread = bank.asset_credit_spread,
        liabilities = [bank.liabilities[i] for i in indices],
        risk_free_rate = bank.risk_free_rate,
        stress_rollover_failure = bank.stress_rollover_failure,
    )
end

function _index_permutations(xs::Vector{Int})
    isempty(xs) && return [Int[]]
    result = Vector{Vector{Int}}()
    for (pos, x) in enumerate(xs)
        rest = [y for (j, y) in enumerate(xs) if j != pos]
        for suffix in _index_permutations(rest)
            push!(result, [x; suffix])
        end
    end
    return result
end

"""
    cost_under_severer_scenario(bank, x_actual)

Calcula o custo do LB efetivamente realizado quando o estresse real é maior
que o cenário planejado. Retorna NamedTuple com:
- `planned_lb`: tamanho do LB construído ex-ante com x_planned
- `realized_gap`: tamanho real dos funding gaps com x_actual
- `shortfall`: déficit (positivo se o LB foi insuficiente)
- `breach`: bool indicando se houve breach
"""
function cost_under_severer_scenario(bank::StressBank, x_actual::Float64)
    bank_actual = StressBank(
        name = bank.name * " (real)",
        asset_notional = bank.asset_notional,
        asset_maturity = bank.asset_maturity,
        asset_credit_spread = bank.asset_credit_spread,
        liabilities = bank.liabilities,
        risk_free_rate = bank.risk_free_rate,
        stress_rollover_failure = x_actual,
    )
    planned = lb_initial(bank)
    realized = lb_initial(bank_actual)
    shortfall = max(realized - planned, 0.0)
    return (
        planned_lb = planned,
        realized_gap = realized,
        shortfall = shortfall,
        breach = shortfall > 0,
    )
end

"""
    breach_horizon(bank, x_actual)

Identifica em qual data de rollover o LB pré-construído (com x_planned) seria
exaurido sob estresse real x_actual > x_planned. Retorna o período em que o
breach ocorre, ou `nothing` se o LB cobre o horizonte inteiro.
"""
function breach_horizon(bank::StressBank, x_actual::Float64)
    planned_lb = lb_initial(bank)
    bank_actual = StressBank(
        name = bank.name * " (real)",
        asset_notional = bank.asset_notional,
        asset_maturity = bank.asset_maturity,
        asset_credit_spread = bank.asset_credit_spread,
        liabilities = bank.liabilities,
        risk_free_rate = bank.risk_free_rate,
        stress_rollover_failure = x_actual,
    )
    cumulative_gap = 0.0
    events = Tuple{Int, Float64}[]
    for liab in bank_actual.liabilities
        for (t, gap) in funding_gap_schedule(liab, x_actual, bank_actual.asset_maturity)
            push!(events, (t, gap))
        end
    end
    sort!(events, by = first)
    for (t, gap) in events
        cumulative_gap += gap
        if cumulative_gap > planned_lb
            return t
        end
    end
    return nothing
end

"""
    summary_lb_cost(bank)

Imprime relatório formatado com tamanho do LB, custo de carrego, alocação por
passivo e indicadores agregados.
"""
function summary_lb_cost(bank::StressBank)
    println("="^72)
    println("Custo do Buffer de Liquidez — $(bank.name)")
    println("="^72)
    @printf "Ativo: K = %.2f, prazo %d períodos\n" bank.asset_notional bank.asset_maturity
    @printf "Estresse de rollover: x%% = %.1f%%\n" 100 * bank.stress_rollover_failure
    @printf "Taxa risk-free: r_f = %.2f%% por período\n\n" 100 * bank.risk_free_rate

    println("Passivos:")
    for liab in bank.liabilities
        @printf "  %-20s prazo = %d, notional = %.2f, sB = %.0f bps\n" liab.name liab.maturity_periods liab.notional 10000 * liab.funding_spread
    end

    lb0 = lb_initial(bank)
    println("\n", "-"^72)
    @printf "LB(0) = %.4f (= %.2f%% do funding total)\n" lb0 100 * lb0 / sum(l.notional for l in bank.liabilities)

    println("\nTrajetória do saldo do LB:")
    for (t, balance) in lb_balance_path(bank)
        @printf "  t = %d → LB = %.4f\n" t balance
    end

    println("\nP&L do LB em economia sem default: ", round(lb_cost_riskfree(bank), digits = 6))
    @printf "Custo do LB com funding spread: %.4f\n" lb_cost_with_spread(bank)

    println("\nAlocação pro-rata por passivo:")
    for (name, cost) in allocate_cost_by_liability(bank)
        @printf "  %-20s : %.4f\n" name cost
    end

    println("\nAlocação marginal por passivo:")
    for (name, cost) in marginal_cost_by_liability(bank)
        @printf "  %-20s : %.4f\n" name cost
    end
    println("="^72)
    return nothing
end
