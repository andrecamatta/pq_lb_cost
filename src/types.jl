"""
    Liability

Passivo único usado para financiar o ativo. Define maturidade e participação
no nominal total de captação.

# Campos
- `name`: identificação
- `notional`: valor de captação (mesma unidade de K do ativo)
- `maturity_periods`: prazo em períodos de renovação (1 = um período por ciclo de renovação)
- `funding_spread`: sB pago pelo banco sobre o risk-free (em fração, ex.: 0.01 = 100 bps)
- `rollover_failure`: x% específico do passivo que não se renova em estresse.
  Se `nothing`, usa o x% do banco.
"""
Base.@kwdef struct Liability
    name::String
    notional::Float64
    maturity_periods::Int
    funding_spread::Float64 = 0.0
    rollover_failure::Union{Nothing, Float64} = nothing
end

"""
    FundingSource

Fonte elegível para uma otimização de mix de funding. Os limites mínimo e
máximo são pesos no funding total.
"""
Base.@kwdef struct FundingSource
    name::String
    maturity_periods::Int
    funding_spread::Float64
    rollover_failure::Float64
    min_weight::Float64 = 0.0
    max_weight::Float64 = 1.0
end

"""
    StressBank

Banco estilizado seguindo o exemplo canônico de Castagna e Fede (2013, §7.3).

Um único ativo de prazo `asset_maturity` (em períodos), financiado por um
ou mais passivos. Em cada data de renovação, uma fração `x%` do passivo não
é renovada no cenário de estresse. O LB pré-construído cobre a dificuldade de
renovar esses passivos.

# Campos
- `name`: identificação do banco
- `asset_notional`: K, valor do ativo
- `asset_maturity`: T_A, prazo do ativo em períodos
- `asset_credit_spread`: sA, spread de crédito do ativo (compensa default risk do issuer)
- `liabilities`: vetor de Liability que financiam o ativo
- `risk_free_rate`: r_f por período
- `stress_rollover_failure`: x% padrão, usado quando o passivo não define x% próprio
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
    FundingMixOptimizationResult

Resultado da otimização de mix de funding. `bank` contém os passivos já
dimensionados no notional ótimo.
"""
Base.@kwdef struct FundingMixOptimizationResult
    bank::StressBank
    direct_funding_cost::Float64
    buffer_cost::Float64
    total_cost::Float64
    buffer_cost_share::Float64
    unit_direct_costs::Dict{String, Float64}
    unit_buffer_costs::Dict{String, Float64}
    unit_total_costs::Dict{String, Float64}
end

"""
    total_funding(bank)

Soma dos notional dos passivos do banco.
"""
total_funding(bank::StressBank) = sum(l.notional for l in bank.liabilities)

"""
    rollover_failure(liability, bank)

Retorna o x% efetivo do passivo: valor específico do passivo quando informado,
ou o cenário padrão do banco caso contrário.
"""
rollover_failure(liability::Liability, bank::StressBank) =
    something(liability.rollover_failure, bank.stress_rollover_failure)
