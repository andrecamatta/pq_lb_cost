"""
    canonical_setup()

Reproduz o exemplo canônico de Castagna e Fede (2013, §7.3): banco com
ativo de 3 períodos financiado por um único passivo de 1 período. Com
x% = 10% de falha por rollover, o LB(0) = K(1 - (1-0.1)^2) = 0.19 K.

Retorna um StressBank pronto para análise.
"""
function canonical_setup(; K::Float64 = 100.0, x_pct::Float64 = 0.10, sB::Float64 = 0.01)
    return StressBank(
        name = "Caso canônico Castagna-Fede",
        asset_notional = K,
        asset_maturity = 3,
        asset_credit_spread = 0.02,
        liabilities = [
            Liability(name = "Bond 1y", notional = K, maturity_periods = 1, funding_spread = sB),
        ],
        risk_free_rate = 0.03,
        stress_rollover_failure = x_pct,
    )
end

"""
    multi_liabilities_setup()

Caso §7.4 com vários passivos (de prazos diferentes) financiando o mesmo
ativo de 6 períodos. Os passivos têm spreads distintos, refletindo perfis
de risco e prazo diversos.
"""
function multi_liabilities_setup(; K::Float64 = 100.0, x_pct::Float64 = 0.10)
    return StressBank(
        name = "§7.4 vários passivos",
        asset_notional = K,
        asset_maturity = 6,
        asset_credit_spread = 0.02,
        liabilities = [
            Liability(name = "Depósito 1y", notional = 0.4 * K, maturity_periods = 1, funding_spread = 0.005),
            Liability(name = "Bond 2y", notional = 0.4 * K, maturity_periods = 2, funding_spread = 0.012),
            Liability(name = "Bond 3y", notional = 0.2 * K, maturity_periods = 3, funding_spread = 0.020),
        ],
        risk_free_rate = 0.03,
        stress_rollover_failure = x_pct,
    )
end

"""
    differentiated_runoff_setup()

Caso com x% específico por passivo. Representa uma aproximação mais realista
para FTP, na qual depósitos, funding atacadista e dívida sênior não têm a
mesma probabilidade de falhar na renovação.
"""
function differentiated_runoff_setup(; K::Float64 = 1000.0)
    return StressBank(
        name = "Runoff diferenciado por passivo",
        asset_notional = K,
        asset_maturity = 6,
        asset_credit_spread = 0.02,
        liabilities = [
            Liability(name = "Depósito varejo 1y", notional = 0.4 * K, maturity_periods = 1, funding_spread = 0.003, rollover_failure = 0.05),
            Liability(name = "CDB atacado 1y", notional = 0.3 * K, maturity_periods = 1, funding_spread = 0.008, rollover_failure = 0.15),
            Liability(name = "LF 2y", notional = 0.2 * K, maturity_periods = 2, funding_spread = 0.012, rollover_failure = 0.10),
            Liability(name = "Senior 3y", notional = 0.1 * K, maturity_periods = 3, funding_spread = 0.020, rollover_failure = 0.08),
        ],
        risk_free_rate = 0.03,
        stress_rollover_failure = 0.10,
    )
end

"""
    brazilian_setup()

Calibração para banco brasileiro de S1, com captação predominante em CDB
(prazos curtos) e Letras Financeiras (prazos médios). Spreads referenciam
o índice ILFS1 da B3 e CDBs típicos de bancos S1.
"""
function brazilian_setup(; K::Float64 = 100.0, x_pct::Float64 = 0.15)
    return StressBank(
        name = "Banco S1 Brasileiro",
        asset_notional = K,
        asset_maturity = 6,
        asset_credit_spread = 0.025,
        liabilities = [
            Liability(name = "CDB 1y", notional = 0.5 * K, maturity_periods = 1, funding_spread = 0.003),
            Liability(name = "LF 2y", notional = 0.3 * K, maturity_periods = 2, funding_spread = 0.010),
            Liability(name = "LF 3y", notional = 0.2 * K, maturity_periods = 3, funding_spread = 0.015),
        ],
        risk_free_rate = 0.115,
        stress_rollover_failure = x_pct,
    )
end

"""
    european_setup()

Calibração para banco europeu G-SII com mix de bonds senior unsecured e
covered bonds. Spreads referenciam ASW de senior unsecured (~80-150 bps).
"""
function european_setup(; K::Float64 = 100.0, x_pct::Float64 = 0.10)
    return StressBank(
        name = "Banco Europeu G-SII",
        asset_notional = K,
        asset_maturity = 6,
        asset_credit_spread = 0.020,
        liabilities = [
            Liability(name = "Senior unsecured 1y", notional = 0.3 * K, maturity_periods = 1, funding_spread = 0.008),
            Liability(name = "Senior unsecured 2y", notional = 0.4 * K, maturity_periods = 2, funding_spread = 0.012),
            Liability(name = "Covered bond 3y", notional = 0.3 * K, maturity_periods = 3, funding_spread = 0.005),
        ],
        risk_free_rate = 0.025,
        stress_rollover_failure = x_pct,
    )
end
