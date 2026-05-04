# pq_lb_cost

Pacote Julia que implementa o cálculo do custo do buffer de liquidez (LB) em
bancos sob dificuldade de renovação dos passivos, com base nas Propositions
7.3.1-7.3.6 de Castagna e Fede (2013, *Measuring and Managing Liquidity Risk*,
Cap. 7).

Código de apoio do artigo "O custo do buffer de liquidez sob funding spread"
(Pílulas de Quant). O foco atual é didático: reproduzir o caso canônico e usar
um programa linear em JuMP/HiGHS para comparar o mix de funding ótimo sem e com
o custo do buffer.

## Escopo

Modela um banco estilizado com um ativo de prazo `T_A` financiado por uma ou
mais fontes de funding, e calcula:

- `AVL(0,T)`, o funding disponível após renovações sob estresse.
- `LB(0)`, o buffer construído em `t = 0` para cobrir gaps provocados pela
  dificuldade de renovar passivos.
- Trajetória do saldo do LB ao longo do horizonte do ativo.
- P&L do LB em economia sem default, verificado numericamente como zero.
- Custo do LB em economia com funding spread `sB`.
- Custo direto de funding em valor presente.
- Otimização linear de mix de funding, comparando a função objetivo sem e com
  o custo em valor presente do buffer.

O custo calculado aqui é o custo incremental do buffer de liquidez, não o custo
total de funding do balanço. O banco já precisa financiar o ativo. O LB adiciona
um estoque líquido pré-posicionado para cobrir a dificuldade de renovar os
passivos, e o custo medido é o spread de captação aplicado a esse estoque
durante o horizonte em que ele precisa ficar disponível.

O pacote é didático. Não substitui sistemas de produção de tesouraria como
Moody's RiskAuthority, Wolters Kluwer OneSumX ou FIS Ambit Liquidity.

## Instalação

```julia
] activate .
] instantiate
```

## Uso mínimo

```julia
using PQLBCost

# Caso canônico Castagna-Fede: ativo de 3 períodos, passivo de 1 período,
# x = 10%, sB = 100 bps.
bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
summary_lb_cost(bank)
```

## Otimização

```julia
using PQLBCost

sources = [
    FundingSource(name = "Depósito varejo", maturity_periods = 1,
                  funding_spread = 0.0045, rollover_failure = 0.05,
                  min_weight = 0.20, max_weight = 0.70),
    FundingSource(name = "CDB atacado", maturity_periods = 1,
                  funding_spread = 0.0042, rollover_failure = 0.30,
                  min_weight = 0.00, max_weight = 0.60),
    FundingSource(name = "LF 2y", maturity_periods = 2,
                  funding_spread = 0.0120, rollover_failure = 0.10,
                  min_weight = 0.10, max_weight = 0.50),
    FundingSource(name = "Senior 3y", maturity_periods = 3,
                  funding_spread = 0.0200, rollover_failure = 0.08,
                  min_weight = 0.10, max_weight = 0.40),
]

without_buffer = optimize_funding_mix(sources; include_buffer_cost = false)
with_buffer = optimize_funding_mix(sources; include_buffer_cost = true)
```

O programa minimiza:

```text
sum_j w_j c_j^funding                 # sem custo do buffer
sum_j w_j (c_j^funding + c_j^buffer)  # com custo do buffer
```

sujeito a:

```text
sum_j w_j = 1
w_j_min <= w_j <= w_j_max
```

Como `sB` e `x%` entram como parâmetros de cenário, o custo unitário de cada
fonte é constante e o problema é linear.

## Exemplos

- `examples/canonical.jl`: caso canônico do livro com verificação de P&L zero.
- `examples/default_economy.jl`: comparação entre economia sem default e
  economia com `sB`.
- `examples/cost_surface.jl`: superfície de sensibilidade custo vs `x%` e
  `sB`, com CSV em `outputs/cost_surface.csv`.
- `examples/optimize_funding_mix.jl`: programa linear para comparar o mix
  ótimo sem e com custo do buffer.

Executar:

```bash
julia examples/optimize_funding_mix.jl
```

## Testes

```julia
] test
```

Testes cobrem: equação 7.1, caso canônico, P&L zero sem default, custo positivo
com `sB`, monotonicidade em `x%`, estrutura a termo de `sB` e otimização linear
de mix de funding.

## Experimentos para o leitor

1. Rode `examples/optimize_funding_mix.jl` e compare o mix ótimo quando o
   objetivo ignora o buffer com o mix ótimo quando o custo do buffer entra na
   função objetivo.
2. Altere `rollover_failure` do CDB atacado e observe quando ele deixa de ser
   atraente apesar do spread direto menor.
3. Aperte `max_weight` do depósito de varejo e observe quanto do benefício de
   estabilidade precisa ser substituído por prazo mais longo.
4. Rode `examples/cost_surface.jl` para ver como `x%` e `sB` afetam o custo do
   buffer no caso canônico.

## Estrutura

```text
src/
  PQLBCost.jl     # módulo principal
  types.jl        # Liability, FundingSource, StressBank
  buffer.jl       # available_funding, lb_initial, lb_cost_*
  optimization.jl # direct_funding_spread_cost, optimize_funding_mix
  scenarios.jl    # canonical_setup
examples/
  canonical.jl
  default_economy.jl
  cost_surface.jl
  optimize_funding_mix.jl
test/
  runtests.jl
outputs/
  cost_surface.csv  # gerado por examples/cost_surface.jl
```

## Referências

- CASTAGNA, A.; FEDE, F. *Measuring and Managing Liquidity Risk*. Wiley Finance, 2013.
- BCBS. *Principles for Sound Liquidity Risk Management and Supervision* (BCBS 144), 2008.
- CEBS. *Guidelines on Liquidity Cost-Benefit Allocation*, 2010.
- GRANT, J. *Liquidity Transfer Pricing: A Guide to Better Practice*. BIS FSI Paper 10, 2011.
- FEDERAL RESERVE. *Interagency Guidance on Funds Transfer Pricing* (SR 16-3), 2016.

## Licença

MIT.
