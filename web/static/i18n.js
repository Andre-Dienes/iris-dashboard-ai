/* IRIS Data Copilot - UI translations (EN-US / PT-BR). Add a language by adding a block to I18N. */
'use strict';

const I18N = {
  pt: {
    locale: 'pt-BR', htmlLang: 'pt-BR',
    // login
    'login.tagline': 'Pergunte aos seus dados em linguagem natural',
    'login.intro': 'Entre com seu usuário do InterSystems IRIS. O portal respeita os privilégios SQL do seu usuário.',
    'login.user': 'Usuário', 'login.password': 'Senha', 'login.submit': 'Entrar', 'login.failed': 'Falha no login',
    // shell
    'brand.tagline': 'AI Hub · SQL sem código',
    'nav.ask': 'Perguntar', 'nav.dashboards': 'Dashboards', 'nav.editor': 'Editor SQL', 'nav.views': 'Views', 'nav.catalog': 'Catálogo', 'nav.history': 'Histórico',
    'title.ask': 'Perguntar', 'title.dashboards': 'Dashboards', 'title.editor': 'Editor SQL', 'title.views': 'Views', 'title.catalog': 'Catálogo de dados', 'title.history': 'Histórico',
    'top.sources': 'Fontes:', 'top.all': 'todas', 'top.logout': 'Sair', 'top.language': 'Idioma',
    'sources.head': 'Esquemas usados pela IA', 'sources.all': 'todos', 'sources.tables': 'tab', 'sources.views': 'views',
    'sources.hint': 'Restringir os esquemas deixa o contexto menor e as respostas mais precisas em bancos grandes.',
    'llm.on': 'AI Hub', 'llm.calls': '{n} chamadas hoje · {t} tokens', 'llm.off': 'LLM não configurado', 'llm.offHint': 'Defina LLM_API_KEY no .env',
    // ask
    'ask.welcome': 'O que você quer descobrir hoje?',
    'ask.intro': 'Escreva sua pergunta em linguagem natural. A IA do <b>InterSystems AI Hub</b> lê o catálogo do IRIS, monta o SQL com os JOINs certos, executa, corrige erros sozinha e sugere o melhor gráfico.',
    'ask.suggestBtn': '✨ Sugerir perguntas a partir dos meus dados', 'ask.suggesting': 'Gerando sugestões…',
    'ask.modeSql': 'Consulta SQL', 'ask.modeSqlTip': 'Gera uma consulta SQL, executa e mostra gráfico/tabela',
    'ask.modeAgent': 'Analista IA', 'ask.modeAgentTip': 'Agente autônomo (%AI.Agent) que explora o banco com ferramentas e responde com análise',
    'ask.phSql': 'Ex.: Qual o faturamento por região nos últimos 6 meses, comparado com o mesmo período do ano anterior?',
    'ask.phAgent': 'Ex.: Investigue por que o faturamento da região Midwest caiu e sugira ações.',
    'ask.send': 'Enviar', 'ask.hint': 'Enter envia · Shift+Enter quebra linha', 'ask.newChat': 'Nova conversa',
    'ask.stepsSql': ['Lendo o catálogo do IRIS…', 'Gerando SQL com o AI Hub…', 'Executando no IRIS…', 'Validando o resultado…'],
    'ask.stepsAgent': ['O agente está explorando o banco…', 'Consultando tabelas com as ferramentas do AI Hub…', 'Cruzando resultados…', 'Escrevendo a análise…'],
    'ask.agentQueries': '{n} consulta(s) executada(s) pelo agente:', 'ask.viewResult': 'Ver resultado {n}', 'ask.agentQuery': 'Consulta do agente',
    'ask.defaults': [
      'Qual o faturamento por mês nos últimos 12 meses?',
      'Top 10 produtos mais vendidos em quantidade este ano, com a categoria',
      'Faturamento e ticket médio por região e canal de venda',
      'Qual foi a média de faturamento por cliente no último mês?',
      'Participação de cada forma de pagamento no valor pago',
      'Quais produtos estão abaixo do estoque mínimo e em quais filiais?',
    ],
    // result card
    'res.default': 'Resultado', 'res.rows': '{n} linha(s)', 'res.limited': ' (limitado)', 'res.ai': 'IA {s} s',
    'res.autofixed': 'autocorrigida ({n} tentativas)', 'res.autofixedTip': 'A IA recebeu o erro do IRIS e corrigiu a consulta automaticamente',
    'res.fix': '🪄 Corrigir com IA', 'res.fixing': 'Corrigindo…', 'res.openEditor': 'Abrir no editor',
    'res.chart': '📈 Gráfico', 'res.table': '▦ Tabela', 'res.chartType': 'Tipo de gráfico',
    'res.addDash': '📊 Adicionar ao dashboard', 'res.createView': '🧩 Criar view', 'res.insight': '✨ Analisar resultado', 'res.tune': '🪄 Ajustar', 'res.editor': '⌨ Editor',
    'res.sql': 'SQL gerado', 'res.copy': 'Copiar', 'res.copied': 'SQL copiado', 'res.noRows': 'A consulta não retornou linhas.',
    'res.showing': 'Mostrando {a} de {b} linhas (exporte CSV para ver tudo).', 'res.empty': '(vazio)', 'res.csvName': 'resultado',
    'res.analyzing': 'Analisando o resultado…',
    'tune.title': 'Ajustar consulta com IA', 'tune.label': 'O que você quer mudar?', 'tune.ph': 'Ex.: incluir só pedidos entregues, separar por canal, mostrar os 5 maiores…', 'tune.ok': 'Ajustar', 'tune.working': 'A IA está ajustando a consulta…',
    // chart types
    'chart.bar': 'Barras', 'chart.hbar': 'Barras horizontais', 'chart.line': 'Linha', 'chart.area': 'Área', 'chart.pie': 'Pizza', 'chart.doughnut': 'Rosca', 'chart.scatter': 'Dispersão', 'chart.kpi': 'Indicador (KPI)', 'chart.table': 'Tabela',
    'width.full': 'Inteira',
    // dialogs
    'dlg.cancel': 'Cancelar', 'dlg.save': 'Salvar',
    'add.title': 'Adicionar ao dashboard', 'add.dashboard': 'Dashboard', 'add.new': '➕ Novo dashboard…', 'add.newName': 'Nome do novo dashboard', 'add.newNamePh': 'Ex.: Comercial — visão diária',
    'add.newNameHint': 'Usado só se escolher "Novo dashboard"', 'add.widgetTitle': 'Título do widget', 'add.viz': 'Visualização', 'add.width': 'Largura', 'add.ok': 'Adicionar',
    'add.done': 'Widget adicionado ao dashboard ✔', 'add.defaultName': 'Novo dashboard',
    'view.title': 'Criar view no IRIS', 'view.name': 'Nome da view (esquema {s})', 'view.hint': 'Letras, números e _. A view fica disponível para qualquer ferramenta SQL (ODBC/JDBC, BI, Excel).',
    'view.desc': 'Descrição', 'view.ok': 'Criar view', 'view.done': 'View {n} criada ✔', 'view.default': 'MinhaView',
    // editor
    'ed.ph': 'SELECT TOP 10 ... (Ctrl+Enter executa)', 'ed.run': '▶ Executar', 'ed.explain': '💡 Explicar com IA', 'ed.tune': '🪄 Ajustar com IA',
    'ed.limit': 'Somente SELECT · até {n} linhas', 'ed.running': 'Executando no IRIS…', 'ed.error': 'Erro na consulta', 'ed.reading': 'A IA está lendo a consulta…',
    'ed.explanation': '💡 Explicação', 'ed.tuneTitle': 'Ajustar com IA', 'ed.tuneChange': 'O que mudar na consulta?', 'ed.tuneDescribe': 'Descreva a consulta que você quer',
    'ed.generate': 'Gerar', 'ed.generating': 'Gerando SQL…', 'ed.tuned': 'Consulta ajustada',
    // dashboards
    'dash.new': '+ Novo', 'dash.gen': '✨ Gerar com IA', 'dash.live': '● AO VIVO', 'dash.refresh': 'Atualizar', 'dash.manual': 'manual', 'dash.reloadTip': 'Atualizar agora',
    'dash.rename': 'Renomear', 'dash.delete': 'Excluir', 'dash.emptyTitle': 'Nenhum widget ainda',
    'dash.emptyText': 'Faça uma pergunta em <b>Perguntar</b> e clique em <b>Adicionar ao dashboard</b>, ou use <b>✨ Gerar com IA</b> descrevendo o painel que você quer.',
    'dash.loading': 'Carregando…', 'dash.sqlTip': 'Ver SQL no editor', 'dash.editTip': 'Editar', 'dash.removeTip': 'Remover',
    'dash.updated': 'Atualizado {t}', 'dash.rowsMs': '{n} linha(s) · {ms} ms',
    'dash.editTitle': 'Editar widget', 'dash.wTitle': 'Título', 'dash.x': 'Eixo X / categoria', 'dash.y': 'Valores (separados por vírgula)', 'dash.series': 'Coluna de séries (opcional)',
    'dash.confirmRemove': 'Remover o widget "{n}"?', 'dash.genTitle': '✨ Gerar dashboard com IA', 'dash.genLabel': 'Descreva o painel que você precisa',
    'dash.genPh': 'Ex.: Painel executivo de vendas: faturamento do mês, ticket médio, pedidos cancelados, evolução mensal por canal, ranking de filiais e categorias mais rentáveis.',
    'dash.genSteps': ['Lendo o catálogo do IRIS…', 'Desenhando os indicadores…', 'Escrevendo as consultas SQL…', 'Testando cada consulta no IRIS…', 'Corrigindo o que falhou…', 'Montando o painel…'],
    'dash.skipped': '{n} widget(s) descartado(s) por erro de SQL', 'dash.created': 'Dashboard criado ✔',
    'dash.newTitle': 'Novo dashboard', 'dash.name': 'Nome', 'dash.desc': 'Descrição', 'dash.create': 'Criar', 'dash.renameTitle': 'Renomear dashboard',
    'dash.confirmDelete': 'Excluir o dashboard "{n}" e todos os seus widgets?',
    // views
    'views.intro': 'Views criadas pelo portal no esquema <b id="viewSchema">{s}</b>. Elas aparecem para qualquer ferramenta SQL do IRIS (ODBC/JDBC, BI, Excel) e também viram fonte para novas perguntas.',
    'views.none': 'Nenhuma view criada ainda', 'views.noneHint': 'Faça uma pergunta e use "Criar view" no resultado.', 'views.by': 'por {u} em {d}',
    'views.query': 'Consultar', 'views.ask': 'Perguntar sobre', 'views.askPrefix': 'Usando a view {n}, ', 'views.delete': 'Excluir', 'views.confirmDelete': 'Excluir a view {n}?',
    // catalog / glossary
    'gl.title': '📘 Glossário de negócio', 'gl.add': '+ Novo termo',
    'gl.intro': 'Definições oficiais que a IA é obrigada a seguir em todas as perguntas, dashboards e análises (ex.: o que conta como faturamento, qual período é "último mês").',
    'gl.none': 'Nenhum termo cadastrado.', 'gl.active': 'ativo', 'gl.inactive': 'inativo', 'gl.edit': 'Editar', 'gl.delete': 'Excluir', 'gl.confirmDelete': 'Excluir o termo "{n}"?',
    'gl.editTitle': 'Editar termo do glossário', 'gl.newTitle': 'Novo termo do glossário', 'gl.term': 'Termo (e sinônimos)', 'gl.termPh': 'Ex.: Cliente inadimplente',
    'gl.def': 'Definição oficial', 'gl.defPh': 'Em linguagem natural e/ou SQL. Ex.: cliente com pagamento Recusado nos últimos 60 dias.',
    'gl.status': 'Situação', 'gl.statusOn': 'Ativo (a IA usa)', 'gl.statusOff': 'Inativo', 'gl.saved': 'Glossário atualizado ✔ — a IA já usa a nova definição',
    'cat.filter': 'Filtrar tabelas e colunas…', 'cat.refresh': '↻ Recarregar catálogo', 'cat.reading': 'Lendo o dicionário do IRIS…',
    'cat.preview': 'Visualizar dados', 'cat.ask': 'Perguntar sobre esta tabela', 'cat.askPrefix': 'Sobre {n}: ', 'cat.nothing': 'Nada encontrado.',
    // history
    'hist.empty': 'Sem histórico ainda.', 'hist.kind.ask': 'Pergunta', 'hist.kind.agent': 'Agente', 'hist.kind.fix': 'Ajuste IA', 'hist.kind.run': 'SQL',
    'hist.meta': '{n} linha(s) · {ms} ms', 'hist.attempts': ' · {n} tentativas', 'hist.reopen': 'Reabrir', 'hist.askAgain': 'Perguntar de novo',
    // generic
    'err.session': 'Sessão expirada.', 'err.http': 'Erro HTTP {n}',
  },
  en: {
    locale: 'en-US', htmlLang: 'en',
    'login.tagline': 'Ask your data in plain language',
    'login.intro': 'Sign in with your InterSystems IRIS user. The portal enforces your user\'s SQL privileges.',
    'login.user': 'User', 'login.password': 'Password', 'login.submit': 'Sign in', 'login.failed': 'Sign-in failed',
    'brand.tagline': 'AI Hub · No-code SQL',
    'nav.ask': 'Ask', 'nav.dashboards': 'Dashboards', 'nav.editor': 'SQL Editor', 'nav.views': 'Views', 'nav.catalog': 'Catalog', 'nav.history': 'History',
    'title.ask': 'Ask', 'title.dashboards': 'Dashboards', 'title.editor': 'SQL Editor', 'title.views': 'Views', 'title.catalog': 'Data catalog', 'title.history': 'History',
    'top.sources': 'Sources:', 'top.all': 'all', 'top.logout': 'Sign out', 'top.language': 'Language',
    'sources.head': 'Schemas used by the AI', 'sources.all': 'all', 'sources.tables': 'tables', 'sources.views': 'views',
    'sources.hint': 'Narrowing the schemas keeps the context small and answers more accurate on large databases.',
    'llm.on': 'AI Hub', 'llm.calls': '{n} calls today · {t} tokens', 'llm.off': 'LLM not configured', 'llm.offHint': 'Set LLM_API_KEY in .env',
    'ask.welcome': 'What do you want to find out today?',
    'ask.intro': 'Type your question in plain language. <b>InterSystems AI Hub</b> reads the IRIS catalog, writes the SQL with the right JOINs, runs it, fixes its own errors and picks the best chart.',
    'ask.suggestBtn': '✨ Suggest questions from my data', 'ask.suggesting': 'Generating suggestions…',
    'ask.modeSql': 'SQL Query', 'ask.modeSqlTip': 'Generates a SQL query, runs it and shows a chart/table',
    'ask.modeAgent': 'AI Analyst', 'ask.modeAgentTip': 'Autonomous agent (%AI.Agent) that explores the database with tools and answers with an analysis',
    'ask.phSql': 'E.g.: What was revenue by region in the last 6 months, compared with the same period last year?',
    'ask.phAgent': 'E.g.: Investigate why revenue in the Midwest region dropped and suggest actions.',
    'ask.send': 'Send', 'ask.hint': 'Enter to send · Shift+Enter for a new line', 'ask.newChat': 'New conversation',
    'ask.stepsSql': ['Reading the IRIS catalog…', 'Generating SQL with AI Hub…', 'Running on IRIS…', 'Checking the result…'],
    'ask.stepsAgent': ['The agent is exploring the database…', 'Querying tables with AI Hub tools…', 'Cross-checking results…', 'Writing the analysis…'],
    'ask.agentQueries': '{n} query(ies) run by the agent:', 'ask.viewResult': 'View result {n}', 'ask.agentQuery': 'Agent query',
    'ask.defaults': [
      'What was the monthly revenue over the last 12 months?',
      'Top 10 best-selling products by quantity this year, with their category',
      'Revenue and average order value by region and sales channel',
      'What was the average revenue per customer last month?',
      'Share of each payment method in the amount paid',
      'Which products are below minimum stock, and at which branches?',
    ],
    'res.default': 'Result', 'res.rows': '{n} row(s)', 'res.limited': ' (limited)', 'res.ai': 'AI {s} s',
    'res.autofixed': 'self-corrected ({n} attempts)', 'res.autofixedTip': 'The AI received the IRIS error and fixed the query automatically',
    'res.fix': '🪄 Fix with AI', 'res.fixing': 'Fixing…', 'res.openEditor': 'Open in editor',
    'res.chart': '📈 Chart', 'res.table': '▦ Table', 'res.chartType': 'Chart type',
    'res.addDash': '📊 Add to dashboard', 'res.createView': '🧩 Create view', 'res.insight': '✨ Analyze result', 'res.tune': '🪄 Refine', 'res.editor': '⌨ Editor',
    'res.sql': 'Generated SQL', 'res.copy': 'Copy', 'res.copied': 'SQL copied', 'res.noRows': 'The query returned no rows.',
    'res.showing': 'Showing {a} of {b} rows (export CSV to see everything).', 'res.empty': '(empty)', 'res.csvName': 'result',
    'res.analyzing': 'Analyzing the result…',
    'tune.title': 'Refine query with AI', 'tune.label': 'What do you want to change?', 'tune.ph': 'E.g.: only delivered orders, split by channel, show the top 5…', 'tune.ok': 'Refine', 'tune.working': 'The AI is refining the query…',
    'chart.bar': 'Bars', 'chart.hbar': 'Horizontal bars', 'chart.line': 'Line', 'chart.area': 'Area', 'chart.pie': 'Pie', 'chart.doughnut': 'Doughnut', 'chart.scatter': 'Scatter', 'chart.kpi': 'Indicator (KPI)', 'chart.table': 'Table',
    'width.full': 'Full',
    'dlg.cancel': 'Cancel', 'dlg.save': 'Save',
    'add.title': 'Add to dashboard', 'add.dashboard': 'Dashboard', 'add.new': '➕ New dashboard…', 'add.newName': 'New dashboard name', 'add.newNamePh': 'E.g.: Sales — daily view',
    'add.newNameHint': 'Only used if you pick "New dashboard"', 'add.widgetTitle': 'Widget title', 'add.viz': 'Visualization', 'add.width': 'Width', 'add.ok': 'Add',
    'add.done': 'Widget added to dashboard ✔', 'add.defaultName': 'New dashboard',
    'view.title': 'Create view in IRIS', 'view.name': 'View name (schema {s})', 'view.hint': 'Letters, digits and _. The view is available to any SQL tool (ODBC/JDBC, BI, Excel).',
    'view.desc': 'Description', 'view.ok': 'Create view', 'view.done': 'View {n} created ✔', 'view.default': 'MyView',
    'ed.ph': 'SELECT TOP 10 ... (Ctrl+Enter runs)', 'ed.run': '▶ Run', 'ed.explain': '💡 Explain with AI', 'ed.tune': '🪄 Refine with AI',
    'ed.limit': 'SELECT only · up to {n} rows', 'ed.running': 'Running on IRIS…', 'ed.error': 'Query error', 'ed.reading': 'The AI is reading the query…',
    'ed.explanation': '💡 Explanation', 'ed.tuneTitle': 'Refine with AI', 'ed.tuneChange': 'What should change in the query?', 'ed.tuneDescribe': 'Describe the query you want',
    'ed.generate': 'Generate', 'ed.generating': 'Generating SQL…', 'ed.tuned': 'Refined query',
    'dash.new': '+ New', 'dash.gen': '✨ Generate with AI', 'dash.live': '● LIVE', 'dash.refresh': 'Refresh', 'dash.manual': 'manual', 'dash.reloadTip': 'Refresh now',
    'dash.rename': 'Rename', 'dash.delete': 'Delete', 'dash.emptyTitle': 'No widgets yet',
    'dash.emptyText': 'Ask a question in <b>Ask</b> and click <b>Add to dashboard</b>, or use <b>✨ Generate with AI</b> and describe the dashboard you want.',
    'dash.loading': 'Loading…', 'dash.sqlTip': 'View SQL in editor', 'dash.editTip': 'Edit', 'dash.removeTip': 'Remove',
    'dash.updated': 'Updated {t}', 'dash.rowsMs': '{n} row(s) · {ms} ms',
    'dash.editTitle': 'Edit widget', 'dash.wTitle': 'Title', 'dash.x': 'X axis / category', 'dash.y': 'Values (comma separated)', 'dash.series': 'Series column (optional)',
    'dash.confirmRemove': 'Remove widget "{n}"?', 'dash.genTitle': '✨ Generate dashboard with AI', 'dash.genLabel': 'Describe the dashboard you need',
    'dash.genPh': 'E.g.: Executive sales dashboard: revenue this month, average order value, cancelled orders, monthly trend by channel, branch ranking and most profitable categories.',
    'dash.genSteps': ['Reading the IRIS catalog…', 'Designing the indicators…', 'Writing the SQL queries…', 'Testing each query on IRIS…', 'Fixing what failed…', 'Assembling the dashboard…'],
    'dash.skipped': '{n} widget(s) dropped due to SQL errors', 'dash.created': 'Dashboard created ✔',
    'dash.newTitle': 'New dashboard', 'dash.name': 'Name', 'dash.desc': 'Description', 'dash.create': 'Create', 'dash.renameTitle': 'Rename dashboard',
    'dash.confirmDelete': 'Delete dashboard "{n}" and all its widgets?',
    'views.intro': 'Views created by the portal in schema <b id="viewSchema">{s}</b>. They show up in any IRIS SQL tool (ODBC/JDBC, BI, Excel) and can be used as sources for new questions.',
    'views.none': 'No views yet', 'views.noneHint': 'Ask a question and use "Create view" on the result.', 'views.by': 'by {u} on {d}',
    'views.query': 'Query', 'views.ask': 'Ask about it', 'views.askPrefix': 'Using view {n}, ', 'views.delete': 'Delete', 'views.confirmDelete': 'Delete view {n}?',
    'gl.title': '📘 Business glossary', 'gl.add': '+ New term',
    'gl.intro': 'Official definitions the AI must follow in every question, dashboard and analysis (e.g. what counts as revenue, which period "last month" means).',
    'gl.none': 'No terms yet.', 'gl.active': 'active', 'gl.inactive': 'inactive', 'gl.edit': 'Edit', 'gl.delete': 'Delete', 'gl.confirmDelete': 'Delete term "{n}"?',
    'gl.editTitle': 'Edit glossary term', 'gl.newTitle': 'New glossary term', 'gl.term': 'Term (and synonyms)', 'gl.termPh': 'E.g.: Delinquent customer',
    'gl.def': 'Official definition', 'gl.defPh': 'In plain language and/or SQL. E.g.: customer with a Declined payment in the last 60 days.',
    'gl.status': 'Status', 'gl.statusOn': 'Active (used by the AI)', 'gl.statusOff': 'Inactive', 'gl.saved': 'Glossary updated ✔ — the AI already uses the new definition',
    'cat.filter': 'Filter tables and columns…', 'cat.refresh': '↻ Reload catalog', 'cat.reading': 'Reading the IRIS dictionary…',
    'cat.preview': 'Preview data', 'cat.ask': 'Ask about this table', 'cat.askPrefix': 'About {n}: ', 'cat.nothing': 'Nothing found.',
    'hist.empty': 'No history yet.', 'hist.kind.ask': 'Question', 'hist.kind.agent': 'Agent', 'hist.kind.fix': 'AI refine', 'hist.kind.run': 'SQL',
    'hist.meta': '{n} row(s) · {ms} ms', 'hist.attempts': ' · {n} attempts', 'hist.reopen': 'Reopen', 'hist.askAgain': 'Ask again',
    'err.session': 'Session expired.', 'err.http': 'HTTP error {n}',
  },
};

function detectLang() {
  try {
    const saved = localStorage.getItem('copilot.lang');
    if (saved === 'pt' || saved === 'en') return saved;
  } catch { /* storage unavailable */ }
  return (navigator.language || 'en').toLowerCase().startsWith('pt') ? 'pt' : 'en';
}

let LANG = detectLang();

/** Translation with {key} interpolation. Arrays (step/question lists) are returned as they are. */
function t(key, vars) {
  const v = I18N[LANG][key] ?? I18N.en[key] ?? key;
  if (Array.isArray(v) || !vars) return v;
  return v.replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? ''));
}

/** Applies translations to static elements (data-i18n, data-i18n-html, data-i18n-ph, data-i18n-title). */
function applyStaticI18n() {
  document.documentElement.lang = t('htmlLang');
  document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
  document.querySelectorAll('[data-i18n-html]').forEach((el) => { el.innerHTML = t(el.dataset.i18nHtml); });
  document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
  document.querySelectorAll('[data-i18n-title]').forEach((el) => { el.title = t(el.dataset.i18nTitle); });
  document.querySelectorAll('.lang-switch button').forEach((b) => b.classList.toggle('active', b.dataset.lang === LANG));
}
