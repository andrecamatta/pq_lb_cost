# pq_lb_cost

Pacote Julia que implementa o cálculo do custo do buffer de liquidez (LB)
em bancos sob cenários de estresse de rollover, com base nas Propositions
7.3.1-7.3.6 de Castagna e Fede (2013, *Measuring and Managing Liquidity Risk*,
Cap. 7), incluindo a generalização §7.4 (vários passivos) e §7.5
(cenários piores que o previsto).

Companion code do artigo "Maturity mismatch e o custo do buffer de liquidez"
(Pílulas de Quant).

## Escopo

Modela um banco estilizado com um ativo de prazo T_A financiado por um ou
mais passivos de prazos diferentes, e calcula:

- LB(0) construído ex-ante para cobrir funding gaps em cenários de
  rollover stressado (Prop. 7.3.1, 7.3.2; equação 7.1).
- Trajetória do saldo do LB ao longo do horizonte do ativo.
- P&L do LB em economia sem default (Prop. 7.3.3) — verificado numericamente
  como zero.
- Custo do LB em economia com funding spread sB (Prop. 7.3.6).
- Versão geral do custo com term structure de sB (§7.3.4).
- Alocação do custo por passivo: pro-rata e marginal (§7.4).
- Robustez do dimensionamento: cenário real x' > x planejado, breach
  horizon (§7.5).

O pacote é didático. Não substitui sistemas de produção de tesouraria
(Moody's RiskAuthority, Wolters Kluwer OneSumX, FIS Ambit Liquidity).

## Instalação

```julia
] activate .
] instantiate
```

## Uso mínimo

```julia
using PQLBCost

# Caso canônico Castagna-Fede: ativo 3 períodos, passivo 1 período, x=10%, sB=100bps
bank = canonical_setup(K = 100.0, x_pct = 0.10, sB = 0.01)
summary_lb_cost(bank)

# Outros setups pré-calibrados:
bank_br = brazilian_setup()  # banco S1 brasileiro
bank_eu = european_setup()   # banco G-SII europeu
bank_multi = multi_liabilities_setup()  # §7.4 com 3 passivos
```

## Exemplos

- `examples/01_canonical.jl`: caso canônico do livro com verificação de Prop. 7.3.3.
- `examples/02_default_economy.jl`: comparação P&L=0 (sem default) vs custo positivo (com sB).
- `examples/03_multi_liabilities.jl`: vários passivos e alocação pro-rata vs marginal.
- `examples/04_severer_scenario.jl`: §7.5 com estresse real > planejado.

Executar:

```bash
julia examples/01_canonical.jl
```

## Testes

```julia
] test
```

8 testsets cobrindo: equação 7.1, caso canônico, Prop. 7.3.3 (P&L=0),
Prop. 7.3.6 (custo positivo com sB), monotonicidade em x%, §7.4
(alocação por passivo), §7.5 (cenário pior), term structure de sB.

## Estrutura

```
src/
  PQLBCost.jl    # módulo principal
  types.jl       # Liability, StressBank, FundingMix
  buffer.jl      # available_funding, lb_initial, lb_cost_*, allocate_*
  scenarios.jl   # canonical_setup, brazilian_setup, european_setup, multi_liabilities_setup
examples/
  01_canonical.jl
  02_default_economy.jl
  03_multi_liabilities.jl
  04_severer_scenario.jl
test/
  runtests.jl
```

## Referências

- CASTAGNA, A.; FEDE, F. *Measuring and Managing Liquidity Risk*. Wiley Finance, 2013.
- BCBS. *Principles for Sound Liquidity Risk Management and Supervision* (BCBS 144), 2008.
- CEBS. *Guidelines on Liquidity Cost-Benefit Allocation*, 2010.
- GRANT, J. *Liquidity Transfer Pricing: A Guide to Better Practice*. BIS FSI Paper 10, 2011.
- FEDERAL RESERVE. *Interagency Guidance on Funds Transfer Pricing* (SR 16-3), 2016.

## Licença

MIT.
