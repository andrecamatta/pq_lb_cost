using Test
using PQLBCost

@testset "PQLBCost" begin

    @testset "Equação 7.1 (AVL)" begin
        # AVL(0,3) = K (1-x%)^2 com K=100, x=10%
        avl = available_funding(100.0, 0.10, 2)
        @test avl ≈ 100.0 * 0.9^2
        @test avl ≈ 81.0
    end

    @testset "Caso canônico (Prop 7.3.1, 7.3.2)" begin
        bank = canonical_setup(K = 100.0, x_pct = 0.10)
        # Para T_A=3, T_L=1, x=10%: LB(0) = K · (1 - (1-0.1)^2) = 19
        @test lb_initial(bank) ≈ 19.0

        # Trajetória: LB começa em 19, cai para 10 em t=1, cai para 0 em t=2
        path = lb_balance_path(bank)
        @test path[1] == (0, 19.0)
        @test path[2][1] == 1
        @test path[2][2] ≈ 19.0 - 10.0
        @test path[3][1] == 2
        @test path[3][2] ≈ 0.0 atol=1e-10
    end

    @testset "Prop 7.3.3 — P&L = 0 sem default" begin
        bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.0)  # sem funding spread
        @test lb_cost_riskfree(bank) ≈ 0.0
        # Sem spread, o custo with_spread também é zero
        @test lb_cost_with_spread(bank) ≈ 0.0
    end

    @testset "Prop 7.3.6 — custo positivo com funding spread" begin
        bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
        cost = lb_cost_with_spread(bank)
        @test cost > 0
        # Com sB = 1%, K = 100, gaps de 10 e 9 em t=1 e t=2
        # Custo aproximado = 10*0.01*1*D(1) + 9*0.01*2*D(2)
        # D(1) ≈ 1/1.03, D(2) ≈ 1/1.03^2
        expected = 10.0 * 0.01 * 1 / 1.03 + 9.0 * 0.01 * 2 / (1.03^2)
        @test cost ≈ expected atol=0.01
    end

    @testset "Custo monotônico em x%" begin
        b1 = canonical_setup(K = 100.0, x_pct = 0.05, sB = 0.01)
        b2 = canonical_setup(K = 100.0, x_pct = 0.15, sB = 0.01)
        @test lb_cost_with_spread(b2) > lb_cost_with_spread(b1)
        @test lb_initial(b2) > lb_initial(b1)
    end

    @testset "Term structure de sB" begin
        bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
        # Função sB que cresce com horizonte (estresse de longo prazo é maior)
        sB_curve = t -> 0.01 + 0.005 * t
        cost_general = lb_cost_general(bank, sB_curve)
        cost_flat = lb_cost_with_spread(bank)
        @test cost_general > cost_flat
    end

    @testset "Otimização de mix de funding" begin
        sources = [
            FundingSource(name = "Depósito varejo", maturity_periods = 1, funding_spread = 0.0045, rollover_failure = 0.05, min_weight = 0.20, max_weight = 0.70),
            FundingSource(name = "CDB atacado", maturity_periods = 1, funding_spread = 0.0042, rollover_failure = 0.30, min_weight = 0.00, max_weight = 0.60),
            FundingSource(name = "LF 2y", maturity_periods = 2, funding_spread = 0.012, rollover_failure = 0.10, min_weight = 0.10, max_weight = 0.50),
            FundingSource(name = "Senior 3y", maturity_periods = 3, funding_spread = 0.020, rollover_failure = 0.08, min_weight = 0.10, max_weight = 0.40),
        ]
        without_buffer = optimize_funding_mix(sources; include_buffer_cost = false)
        with_buffer = optimize_funding_mix(sources; include_buffer_cost = true)

        weights_without = Dict(l.name => l.notional / total_funding(without_buffer.bank) for l in without_buffer.bank.liabilities)
        weights_with = Dict(l.name => l.notional / total_funding(with_buffer.bank) for l in with_buffer.bank.liabilities)

        @test weights_without["CDB atacado"] ≈ 0.60
        @test weights_with["Depósito varejo"] ≈ 0.70
        @test direct_funding_spread_cost(with_buffer.bank) ≈ with_buffer.direct_funding_cost
        @test lb_cost_with_spread(with_buffer.bank) ≈ with_buffer.buffer_cost
        @test with_buffer.direct_funding_cost > without_buffer.direct_funding_cost
        @test with_buffer.direct_funding_cost + with_buffer.buffer_cost <
              without_buffer.direct_funding_cost + without_buffer.buffer_cost
    end

end
