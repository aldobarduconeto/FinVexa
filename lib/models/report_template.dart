class ReportTemplate {
  const ReportTemplate(this.id, this.title, this.groups);
  final String id, title;
  final Map<String, Map<String, String>> groups;
}

const reportTemplates = [
  ReportTemplate('mensal', 'Relatório mensal', {
    'Resultado': {
      'Receita líquida': 'Receita',
      'Custo dos produtos vendidos': 'Despesa',
      'Lucro bruto': 'Outros',
      'Lucro líquido': 'Lucro',
      'Despesa líquida de IRPJ e CSLL': 'Outros',
      'Despesa financeira líquida': 'Outros',
      'Depreciação e amortização': 'Outros',
    },
    'Balanço e caixa': {
      'Ativo total': 'Outros',
      'Ativo circulante': 'Outros',
      'Ativo total médio': 'Outros',
      'Passivo circulante': 'Outros',
      'Passivo não circulante': 'Outros',
      'Estoques': 'Outros',
      'Estoque médio': 'Outros',
      'Caixa e equivalentes de caixa': 'Caixa',
      'Patrimônio líquido': 'Patrimônio',
      'Patrimônio líquido médio': 'Outros',
      'Dívida bruta': 'Outros',
      'Fluxo de caixa operacional': 'Outros',
      'CAPEX desembolsado': 'Outros',
    },
    'Custos e investimentos': {
      'Custos e despesas fixas': 'Outros',
      'Custos e despesas variáveis': 'Outros',
      'Quantidade vendida': 'Outros',
      'Preço unitário': 'Outros',
      'Custo variável unitário': 'Outros',
      'Retorno líquido do investimento': 'Outros',
      'Custo do investimento': 'Outros',
    },
  }),
  ReportTemplate('dre', 'Demonstração do Resultado (DRE)', {
    'Receita e custos': {
      'Receita bruta': 'Outros',
      'Deduções da receita': 'Outros',
      'Receita líquida': 'Receita',
      'Custo dos produtos vendidos': 'Despesa',
      'Lucro bruto': 'Outros',
    },
    'Despesas e resultado': {
      'Despesas com vendas': 'Despesa',
      'Despesas administrativas': 'Despesa',
      'Resultado operacional': 'Outros',
      'Despesa financeira líquida': 'Outros',
      'Despesa líquida de IRPJ e CSLL': 'Outros',
      'Depreciação e amortização': 'Outros',
      'Lucro líquido': 'Lucro',
    },
  }),
  ReportTemplate('bp', 'Balanço Patrimonial', {
    'Ativo': {
      'Caixa e equivalentes de caixa': 'Caixa',
      'Contas a receber': 'Outros',
      'Estoques': 'Outros',
      'Ativo circulante': 'Outros',
      'Realizável a longo prazo': 'Outros',
      'Imobilizado': 'Outros',
      'Intangível': 'Outros',
      'Ativo não circulante': 'Outros',
      'Ativo total': 'Outros',
    },
    'Passivo e patrimônio': {
      'Fornecedores': 'Outros',
      'Passivo circulante': 'Outros',
      'Passivo não circulante': 'Outros',
      'Dívida bruta': 'Outros',
      'Capital social': 'Outros',
      'Reservas de lucros': 'Outros',
      'Patrimônio líquido': 'Patrimônio',
    },
  }),
  ReportTemplate('dfc', 'Demonstração dos Fluxos de Caixa (DFC)', {
    'Movimentações e saldos': {
      'Caixa inicial': 'Outros',
      'Fluxo de caixa operacional': 'Outros',
      'Fluxo de caixa de investimento': 'Outros',
      'Fluxo de caixa de financiamento': 'Outros',
      'Efeito cambial sobre o caixa': 'Outros',
      'Variação líquida de caixa': 'Outros',
      'Caixa e equivalentes de caixa': 'Caixa',
    },
  }),
  ReportTemplate('dmpl', 'Mutações do Patrimônio Líquido (DMPL)', {
    'Movimentações patrimoniais': {
      'Patrimônio líquido inicial': 'Outros',
      'Aumento de capital': 'Outros',
      'Lucro líquido': 'Lucro',
      'Outros resultados abrangentes': 'Outros',
      'Dividendos distribuídos': 'Outros',
      'Ajustes patrimoniais': 'Outros',
      'Patrimônio líquido': 'Patrimônio',
    },
  }),
  ReportTemplate('dva', 'Demonstração do Valor Adicionado (DVA)', {
    'Geração de riqueza': {
      'Receitas para DVA': 'Outros',
      'Insumos adquiridos de terceiros': 'Outros',
      'Depreciação e amortização': 'Outros',
      'Valor adicionado recebido em transferência': 'Outros',
      'Valor adicionado total a distribuir': 'Outros',
    },
    'Distribuição da riqueza': {
      'Remuneração de pessoal': 'Outros',
      'Impostos, taxas e contribuições': 'Outros',
      'Remuneração de capitais de terceiros': 'Outros',
      'Remuneração de capitais próprios': 'Outros',
    },
  }),
  ReportTemplate('dra', 'Demonstração do Resultado Abrangente (DRA)', {
    'Resultado abrangente': {
      'Lucro líquido': 'Lucro',
      'Outros resultados abrangentes': 'Outros',
      'Resultado abrangente total': 'Outros',
      'Resultado abrangente da controladora': 'Outros',
      'Resultado abrangente de não controladores': 'Outros',
    },
  }),
  ReportTemplate('dlpa', 'Lucros ou Prejuízos Acumulados (DLPA)', {
    'Movimentações de lucros e prejuízos': {
      'Saldo inicial de lucros ou prejuízos acumulados': 'Outros',
      'Ajustes de exercícios anteriores': 'Outros',
      'Lucro líquido': 'Lucro',
      'Transferências para reservas': 'Outros',
      'Dividendos distribuídos': 'Outros',
      'Saldo final de lucros ou prejuízos acumulados': 'Outros',
    },
  }),
  ReportTemplate('balancete', 'Balancete de verificação resumido', {
    'Totais de controle': {
      'Saldo devedor inicial': 'Outros',
      'Saldo credor inicial': 'Outros',
      'Total de débitos': 'Outros',
      'Total de créditos': 'Outros',
      'Saldo devedor final': 'Outros',
      'Saldo credor final': 'Outros',
    },
  }),
  ReportTemplate('orcamento', 'Orçamento e realizado', {
    'Orçado': {
      'Receita orçada': 'Outros',
      'Despesas orçadas': 'Outros',
      'Resultado orçado': 'Outros',
    },
    'Realizado': {
      'Receita realizada': 'Receita',
      'Despesas realizadas': 'Despesa',
      'Resultado realizado': 'Lucro',
    },
  }),
  ReportTemplate('projecao', 'Projeção financeira', {
    'Premissas e valores projetados': {
      'Receita projetada': 'Outros',
      'Custos projetados': 'Outros',
      'Despesas projetadas': 'Outros',
      'Resultado projetado': 'Outros',
      'Fluxo de caixa projetado': 'Outros',
      'Saldo de caixa projetado': 'Outros',
    },
  }),
  ReportTemplate('custos', 'Custos e margem de contribuição', {
    'Custos e volumes': {
      'Receita líquida': 'Receita',
      'Custos e despesas fixas': 'Outros',
      'Custos e despesas variáveis': 'Outros',
      'Custo total': 'Outros',
      'Quantidade vendida': 'Outros',
      'Preço unitário': 'Outros',
      'Custo variável unitário': 'Outros',
    },
  }),
  ReportTemplate('investimentos', 'Investimentos e retorno', {
    'Aplicações e retorno': {
      'Custo do investimento': 'Outros',
      'Retorno líquido do investimento': 'Outros',
      'CAPEX desembolsado': 'Outros',
      'CAPEX previsto': 'Outros',
    },
  }),
  ReportTemplate('receber', 'Contas a receber', {
    'Saldos e vencimentos': {
      'Saldo inicial a receber': 'Outros',
      'Vendas a prazo': 'Outros',
      'Recebimentos': 'Outros',
      'Saldo a receber não vencido': 'Outros',
      'Saldo a receber vencido': 'Outros',
      'Contas a receber': 'Outros',
    },
  }),
  ReportTemplate('pagar', 'Contas a pagar', {
    'Saldos e vencimentos': {
      'Saldo inicial a pagar': 'Outros',
      'Obrigações contraídas': 'Outros',
      'Pagamentos': 'Outros',
      'Saldo a pagar não vencido': 'Outros',
      'Saldo a pagar vencido': 'Outros',
      'Contas a pagar': 'Outros',
    },
  }),
  ReportTemplate('personalizado', 'Relatório personalizado', {}),
];
