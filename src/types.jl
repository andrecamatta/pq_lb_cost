"""
    Liability

Passivo único usado para financiar o ativo. Define maturidade e participação
no nominal total de captação.

# Campos
- `name`: identificação
- `notional`: valor de captação (mesma unidade de K do ativo)
- `maturity_periods`: prazo em períodos de rollover (1 = um período por ciclo de renovação)
- `funding_spread`: sB pago pelo banco sobre o risk-free (em fração, ex.: 0.01 = 100 bps)
"""
Base.@kwdef struct Liability
    name::String
    notional::Float64
    maturity_periods::Int
    funding_spread::Float64 = 0.0
end

"""
    StressBank

Banco estilizado seguindo o exemplo canônico de Castagna e Fede (2013, §7.3).

Um único ativo de prazo `asset_maturity` (em períodos), financiado por um
ou mais passivos. Em cada data de rollover, fração `x%` do passivo a renovar
não é renovada (cenário de estresse). O LB pré-construído cobre essas
falhas de renovação.

# Campos
- `name`: identificação do banco
- `asset_notional`: K, valor do ativo
- `asset_maturity`: T_A, prazo do ativo em períodos
- `asset_credit_spread`: sA, spread de crédito do ativo (compensa default risk do issuer)
- `liabilities`: vetor de Liability que financiam o ativo
- `risk_free_rate`: r_f por período
- `stress_rollover_failure`: x%, fração que falha em cada rollover (0.10 = 10%)
"""
Base.@kwdef struct StressBank
    name::String
    asset_notional::Float64
    asset_maturity::Int
    asset_credit_spread::Float64 = 0.0
    liabilities::Vector{Liability}
    risk_free_rate::Float64 = 0.0
    stress_rollover_failure::Float64 = 0.10
end

"""
    FundingMix

Conveniência para construir um StressBank com vários passivos. Recebe um
vetor de tuplas (nome, notional, maturidade, spread) e retorna o
vetor de Liability correspondente.
"""
function FundingMix(specs::Vector{NTuple{4, Any}})
    return [Liability(name = String(s[1]), notional = Float64(s[2]),
                       maturity_periods = Int(s[3]), funding_spread = Float64(s[4]))
            for s in specs]
end

"""
    total_funding(bank)

Soma dos notional dos passivos do banco.
"""
total_funding(bank::StressBank) = sum(l.notional for l in bank.liabilities)
