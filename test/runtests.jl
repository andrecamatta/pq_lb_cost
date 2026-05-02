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

    @testset "§7.4 vários passivos" begin
        bank = multi_liabilities_setup(K = 100.0, x_pct = 0.10)
        lb0 = lb_initial(bank)
        @test lb0 > 0

        # Alocação por passivo soma ao custo total
        alloc = allocate_cost_by_liability(bank)
        total = sum(values(alloc))
        @test total ≈ lb_cost_with_spread(bank)

        # Alocação marginal soma (após normalização) ao custo total
        marginal = marginal_cost_by_liability(bank)
        total_marginal = sum(values(marginal))
        @test total_marginal ≈ lb_cost_with_spread(bank) atol=1e-6
    end

    @testset "§7.5 cenário pior que o previsto" begin
        bank = canonical_setup(K = 100.0, x_pct = 0.10)
        result = cost_under_severer_scenario(bank, 0.20)
        @test result.realized_gap > result.planned_lb
        @test result.shortfall > 0
        @test result.breach == true

        # Cenário melhor: sem breach
        result2 = cost_under_severer_scenario(bank, 0.05)
        @test result2.shortfall == 0
        @test result2.breach == false
    end

    @testset "Term structure de sB" begin
        bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
        # Função sB que cresce com horizonte (estresse de longo prazo é maior)
        sB_curve = t -> 0.01 + 0.005 * t
        cost_general = lb_cost_general(bank, sB_curve)
        cost_flat = lb_cost_with_spread(bank)
        @test cost_general > cost_flat
    end

    @testset "Spread endógeno e alocação marginal" begin
        bank = multi_liabilities_setup(K = 1000.0, x_pct = 0.18)
        cost_linear = lb_cost_with_spread(bank)
        cost_endogenous = lb_cost_with_endogenous_spread(
            bank;
            threshold_ratio = 0.20,
            crowding_slope = 0.12,
        )
        @test cost_endogenous > cost_linear

        alloc_linear = allocate_cost_by_liability(bank)
        alloc_endogenous = marginal_endogenous_cost_by_liability(
            bank;
            threshold_ratio = 0.20,
            crowding_slope = 0.12,
        )
        @test sum(values(alloc_endogenous)) ≈ cost_endogenous atol=1e-6
        @test any(abs(alloc_endogenous[k] - alloc_linear[k]) > 1e-6 for k in keys(alloc_linear))

        cost_no_crowding = lb_cost_with_endogenous_spread(
            bank;
            threshold_ratio = 1.0,
            crowding_slope = 0.12,
        )
        @test cost_no_crowding ≈ cost_linear
    end

end
