"""
    available_funding(notional, x_pct, n_rollovers)

Calcula o funding disponível em data futura sob dificuldade de renovação dos
passivos, a partir da equação 7.1 de Castagna e Fede (2013):

    AVL(0, T) = K · (1 - x%)^N

Onde K é o nominal inicial, x% é a fração que não se renova em cada evento, e
N é o número de renovações até a data T.
"""
function available_funding(notional::Float64, x_pct::Float64, n_rollovers::Int)
    return notional * (1 - x_pct)^n_rollovers
end

"""
    funding_gap_schedule(liability, x_pct, asset_maturity)

Para um único passivo, retorna o vetor de funding gaps em cada data de
renovação dentro do horizonte do ativo. O passivo de prazo T_L tem
N = floor(T_A / T_L) − 1 renovações internas antes do vencimento do ativo.

Em cada data k = 1, 2, …, N, o gap é a fração não renovada sobre o nominal que
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
        # Em cada data de renovação, o gap é a fração x% sobre o que sobrou.
        outstanding = liability.notional * (1 - x_pct)^(k - 1)
        gap = outstanding * x_pct
        push!(gaps, (k * T_L, gap))
    end
    return gaps
end

"""
    lb_initial(bank)

Tamanho do LB em t=0 que cobre integralmente os funding gaps em todas as
datas de renovação, em todos os passivos do banco.

LB(0) = Σ_j Σ_k FG_j(t_k) onde j indexa passivos e k indexa renovações.

Em forma fechada para um único passivo:
    LB(0) = K · (1 - (1 - x%)^N)
"""
function lb_initial(bank::StressBank)
    total = 0.0
    for liab in bank.liabilities
        for (_, gap) in funding_gap_schedule(liab, rollover_failure(liab, bank), bank.asset_maturity)
            total += gap
        end
    end
    return total
end

"""
    lb_balance_path(bank)

Retorna a trajetória do saldo do LB ao longo do tempo: vetor de tuplas
(t, LB_t). Em t=0, LB começa no tamanho `lb_initial`. Em cada data de
renovação de cada passivo, o LB é decrementado pelo funding gap respectivo.
"""
function lb_balance_path(bank::StressBank)
    # Coleta todos os gaps em todas as datas
    events = Tuple{Int, Float64}[]
    for liab in bank.liabilities
        for (t, gap) in funding_gap_schedule(liab, rollover_failure(liab, bank), bank.asset_maturity)
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
        gaps = funding_gap_schedule(liab, rollover_failure(liab, bank), bank.asset_maturity)
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
buffer ao longo de cada janela de renovação.

Fórmula geral (versão simplificada do §7.3.4 com sB constante por passivo):

    LBC(0) ≈ Σ_j Σ_k D(0,t_k) · sB_j · gap_jk · t_k

Onde D(0,t) é o fator de desconto risk-free e t_k é o tempo durante o qual o
gap precisa estar coberto.

Esta função usa desconto discreto pelo fator `1 / (1 + r_f)^t` e assume sB
constante para cada passivo. Para sB com term structure, usar
`lb_cost_general`.
"""
function lb_cost_with_spread(bank::StressBank)
    rf = bank.risk_free_rate
    cost = 0.0
    for liab in bank.liabilities
        gaps = funding_gap_schedule(liab, rollover_failure(liab, bank), bank.asset_maturity)
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
        gaps = funding_gap_schedule(liab, rollover_failure(liab, bank), bank.asset_maturity)
        for (t_gap, gap) in gaps
            discount = 1.0 / (1 + rf)^t_gap
            carry_cost = gap * sB_curve(t_gap) * t_gap * discount
            cost += carry_cost
        end
    end
    return cost
end

"""
    summary_lb_cost(bank)

Imprime relatório formatado com tamanho do LB, trajetória do buffer e custo de
carrego.
"""
function summary_lb_cost(bank::StressBank)
    println("="^72)
    println("Custo do Buffer de Liquidez — $(bank.name)")
    println("="^72)
    @printf "Ativo: K = %.2f, prazo %d períodos\n" bank.asset_notional bank.asset_maturity
    @printf "Estresse de renovação dos passivos: x%% = %.1f%%\n" 100 * bank.stress_rollover_failure
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
    println("="^72)
    return nothing
end
