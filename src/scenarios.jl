"""
    canonical_setup()

Reproduz o exemplo canônico de Castagna e Fede (2013, §7.3): banco com
ativo de 3 períodos financiado por um único passivo de 1 período. Com
x% = 10% do passivo não renovado em cada evento, o
LB(0) = K(1 - (1-0.1)^2) = 0.19 K.

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
