# pq_lb_cost

Pacote Julia que implementa o cálculo do custo do buffer de liquidez (LB)
em bancos sob cenários de estresse de rollover, com base nas Propositions
7.3.1-7.3.6 de Castagna e Fede (2013, *Measuring and Managing Liquidity Risk*,
Cap. 7). O pacote também inclui extensões didáticas para múltiplos passivos,
runoff diferenciado, spread endógeno de liquidez e otimização linear de mix de
funding com JuMP/HiGHS.

Código de apoio do artigo "O custo do buffer de liquidez sob funding spread"
(Pílulas de Quant).

## Escopo

Modela um banco estilizado com um ativo de prazo `T_A` financiado por um ou
mais passivos de prazos diferentes, e calcula:

- `LB(0)` construído ex-ante para cobrir funding gaps em cenários de rollover
  stressado (Prop. 7.3.1, 7.3.2; equação 7.1).
- Trajetória do saldo do LB ao longo do horizonte do ativo.
- P&L do LB em economia sem default (Prop. 7.3.3), verificado numericamente
  como zero.
- Custo do LB em economia com funding spread `sB` (Prop. 7.3.6).
- Versão geral do custo com estrutura a termo de `sB` (§7.3.4).
- Alocação do custo por passivo: pro-rata, marginal e com spread endógeno.
- Robustez do dimensionamento: cenário real `x' > x` planejado, breach
  horizon (§7.5).
- Otimização linear de mix de funding, comparando a função objetivo sem e com
  o custo em valor presente do buffer.

O custo calculado aqui é o custo incremental do buffer de liquidez, não o custo
total de funding do balanço. O banco já precisa financiar o ativo. O LB adiciona
um estoque líquido pré-posicionado para cobrir gaps de rollover, e o custo
medido é o spread de captação aplicado a esse estoque durante o horizonte em
que ele precisa ficar disponível.

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

# Caso canônico Castagna-Fede: ativo 3 períodos, passivo 1 período,
# x = 10%, sB = 100 bps.
bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
summary_lb_cost(bank)

# Outros setups pré-calibrados:
bank_br = brazilian_setup()
bank_eu = european_setup()
bank_multi = multi_liabilities_setup()
bank_runoff = differentiated_runoff_setup()
```

## Exemplos

- `examples/canonical.jl`: caso canônico do livro com verificação de Prop. 7.3.3.
- `examples/default_economy.jl`: comparação P&L = 0 (sem default) vs custo positivo (com `sB`).
- `examples/multi_liabilities.jl`: vários passivos e alocação pro-rata vs marginal.
- `examples/severer_scenario.jl`: §7.5 com estresse real maior que o planejado.
- `examples/cost_surface.jl`: superfície de sensibilidade custo vs `x%` e `sB`, com CSV em `outputs/cost_surface.csv`.
- `examples/endogenous_spread_allocation.jl`: cenário em que a alocação marginal diverge da pro-rata por spread endógeno de liquidez.
- `examples/differentiated_runoff.jl`: exemplo com `x%` específico por passivo.
- `examples/optimize_funding_mix.jl`: programa linear em JuMP/HiGHS para comparar o mix ótimo sem e com custo do buffer.

Executar:

```bash
julia examples/canonical.jl
```

## Testes

```julia
] test
```

Testes cobrindo: equação 7.1, caso canônico, Prop. 7.3.3 (P&L = 0),
Prop. 7.3.6 (custo positivo com `sB`), monotonicidade em `x%`, §7.4
(alocação por passivo), §7.5 (cenário pior), estrutura a termo de `sB`,
spread endógeno de liquidez, `x%` diferenciado por passivo e otimização linear
de mix de funding.

## Experimentos para o leitor

1. Aumente `x_pct` em `examples/cost_surface.jl` e observe que o LB cresce
   de modo não linear, enquanto o custo continua proporcional ao spread.
2. Troque parte do `CDB 1y` por `LF 3y` em `brazilian_setup()` e compare o
   benefício de prazo maior contra o spread maior da LF.
3. Rode `examples/endogenous_spread_allocation.jl` com `threshold = 0.15`
   e depois com `threshold = 0.30`. A diferença mostra quando a alocação
   marginal passa a importar para FTP.
4. Substitua `sB` constante por uma curva crescente em `lb_cost_general`.
   Esse caso aproxima um banco que só consegue captar em estresse pagando
   prêmios maiores nos horizontes longos.
5. Rode `examples/optimize_funding_mix.jl` e compare o mix ótimo quando o
   objetivo ignora o buffer com o mix ótimo quando o custo do buffer entra na
   função objetivo.

## Estrutura

```text
src/
  PQLBCost.jl     # módulo principal
  types.jl        # Liability, FundingSource, StressBank, FundingMix
  buffer.jl       # available_funding, lb_initial, lb_cost_*, allocate_*
  optimization.jl # direct_funding_spread_cost, optimize_funding_mix
  scenarios.jl    # canonical_setup, brazilian_setup, european_setup, ...
examples/
  canonical.jl
  default_economy.jl
  multi_liabilities.jl
  severer_scenario.jl
  cost_surface.jl
  endogenous_spread_allocation.jl
  differentiated_runoff.jl
  optimize_funding_mix.jl
test/
  runtests.jl
outputs/
  cost_surface.csv  # gerado pelo exemplo 05
```

## Referências

- CASTAGNA, A.; FEDE, F. *Measuring and Managing Liquidity Risk*. Wiley Finance, 2013.
- BCBS. *Principles for Sound Liquidity Risk Management and Supervision* (BCBS 144), 2008.
- CEBS. *Guidelines on Liquidity Cost-Benefit Allocation*, 2010.
- GRANT, J. *Liquidity Transfer Pricing: A Guide to Better Practice*. BIS FSI Paper 10, 2011.
- FEDERAL RESERVE. *Interagency Guidance on Funds Transfer Pricing* (SR 16-3), 2016.

## Licença

MIT.
