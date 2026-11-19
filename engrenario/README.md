# Engrenário

Backlog de jogos com alma de oficina a vapor. O app trata a fila de jogos como
uma caldeira: quanto mais horas pendentes, maior a pressão. Ele ajuda a decidir
o que jogar, limita quantos jogos ficam em andamento e acompanha o progresso
por sessões.

Projeto Final Integrado de Computação Móvel e Programação Orientada a Objetos II.

## Como rodar

Requisitos: Flutter 3.19 ou mais novo, Node.js 20 ou mais novo e PostgreSQL 16
(ou Docker Compose). O Flutter funciona no Chrome, Android e iOS; os dados são
persistidos no PostgreSQL pelo backend Express.

1. Inicie o PostgreSQL. Com Docker Compose, na pasta do projeto:

   ```
   docker compose up -d postgres
   ```

2. Configure e inicie a API:

   ```
   cd backend
   cp .env.example .env
   npm install
   npm run dev
   ```

   O backend cria as tabelas a partir de `../database/schema.sql` ao iniciar.
   Deixe esse terminal aberto. Se usar PostgreSQL instalado localmente em vez
   do Compose, ajuste `DATABASE_URL` em `backend/.env`.

3. Em outro terminal, instale os pacotes Flutter e rode no Chrome:

   ```
   flutter pub get
   flutter run -d chrome \
     --dart-define=API_BASE_URL=http://localhost:3000/api \
     --dart-define=RAWG_KEY=sua_chave
   ```

   Gere uma chave gratuita da RAWG em https://rawg.io/apidocs. Sem ela, o
   catálogo não retorna resultados; o restante do app usa o backend normalmente.

Para Android Emulator, configure o backend para aceitar conexões da rede local
(`HOST=0.0.0.0` no `backend/.env`) e rode o Flutter com
`--dart-define=API_BASE_URL=http://10.0.2.2:3000/api`. Em aparelho físico, use o
IP local do computador no lugar de `10.0.2.2`.

Para gerar um APK de entrega (`flutter build apk`), configure
`API_BASE_URL` para o endereço do backend acessível pelo aparelho:

```
flutter build apk --dart-define=API_BASE_URL=https://seu-backend/api
```

O backend fornecido é para desenvolvimento local e não implementa autenticação.
Não o exponha publicamente sem adicionar autenticação, TLS e configuração segura
de CORS e credenciais.

Testes das regras de negócio: `flutter test`. Verificação do backend:
`cd backend && npm run typecheck`.

## Onde está cada requisito

| Requisito | Onde ver |
|---|---|
| Interface Flutter, navegação, formulários e validações | `lib/screens/` (8 telas) e `lib/screens/formularios.dart` |
| Animações ligadas à rolagem | `lib/widgets/revelar.dart`, `lib/screens/inicio_screen.dart`, `lib/widgets/manometro.dart` |
| Classes e objetos | `lib/models/` |
| Abstração | `Jogo`, `EstrategiaPrioridade`, `Conquista`, `Repositorio<T>`, `CatalogoService` |
| Herança | `JogoCatalogo` e `JogoAcervo` estendem `Jogo`; quatro estratégias estendem `EstrategiaPrioridade`; quatro tipos de conquista estendem `Conquista` |
| Polimorfismo | `legenda` e `horasParaTerminar` em cada tipo de jogo; `pontuar()` em cada estratégia; `progresso()` em cada conquista |
| Encapsulamento | Campos privados de `JogoAcervo` (`_status`, `_horasEstimadas`, `_notaPessoal`) alterados só por métodos que validam |
| API REST e persistência | `backend/src/index.ts`, `lib/data/api_client.dart` e `lib/data/repositorios.dart` |
| Banco de dados PostgreSQL | `database/schema.sql` |
| API externa (HTTP + JSON) | `lib/services/catalogo_service.dart` (RAWG) |
| Regras de negócio | `lib/controllers/acervo_controller.dart` |
| Integração entre as camadas | Tela → `AcervoController` → repositórios (API Express/PostgreSQL) e serviço RAWG |

## Arquitetura

```
lib/
  main.dart                  ponto de entrada
  core/                      tema, formatação, erros, rotas, chave da API
  models/                    Jogo, Sessao, estratégias, conquistas, resumo
  data/                      cliente HTTP e repositórios da API
  services/                  consumo da API RAWG
  controllers/               regras de negócio (AcervoController)
  widgets/                   engrenagens, manômetro, letreiro, placas
  screens/                   telas e formulários
backend/                     API TypeScript + Express
database/schema.sql          estrutura do PostgreSQL
docker-compose.yml           PostgreSQL local para desenvolvimento
test/                        testes das regras
```

As telas nunca falam com o banco nem com a API diretamente. Toda mudança passa
pelo `AcervoController`, que valida a regra, grava pelo repositório HTTP na API
Express e avisa as telas (`ChangeNotifier`), que se redesenham. O backend usa
consultas parametrizadas no PostgreSQL.

## Regras de negócio

1. **Máquina de estados.** Cada jogo está em um de cinco estados (desejado, na
   fila, jogando, zerado, abandonado) e só pode seguir as transições permitidas.
   Um jogo na fila, por exemplo, não vai direto para zerado.
2. **Limite da bancada.** Só é possível jogar N jogos ao mesmo tempo (padrão 3,
   configurável de 1 a 10). O limite não pode ser reduzido abaixo do que já
   está em andamento.
3. **Sem duplicados.** O mesmo jogo da RAWG não entra duas vezes no acervo.
4. **Para zerar** é preciso ter ao menos uma sessão registrada e dar uma nota
   de 0 a 10.
5. **Sessões** só para jogos em andamento, de 5 minutos a 16 horas, nunca no
   futuro nem antes de o jogo entrar no acervo, e a soma de um dia (todos os
   jogos) não passa de 24 horas.
6. **Progresso** = horas jogadas ÷ duração estimada (a estimativa vem da API e
   pode ser ajustada pelo usuário).
7. **Previsão de término** pelo ritmo real das últimas duas semanas; sem
   sessões recentes, divide as horas semanais entre os jogos em andamento.
8. **Pressão do backlog** = horas pendentes ÷ horas de jogo por semana. Um ano
   de fila enche o manômetro; os níveis são estável, aquecendo e crítica.
9. **Priorização da fila** por quatro estratégias intercambiáveis: equilibrada,
   vitória rápida, obra-prima e poeira na estante.
10. **Conquistas** calculadas a partir dos números do acervo.

## Banco de dados

PostgreSQL, três tabelas (script em `database/schema.sql`):

```
jogos (1) ──── (N) sessoes          configuracoes (chave, valor)
```

- `jogos`: dados do catálogo copiados da API mais os dados do usuário (status,
  duração estimada, nota, plataforma, anotações).
- `sessoes`: tempo jogado por dia. Apagar um jogo apaga as sessões dele
  (`ON DELETE CASCADE`).
- `configuracoes`: limite da bancada e horas semanais.

Operações CRUD ficam disponíveis pela API Express. O servidor aplica o schema
ao iniciar, e o PostgreSQL calcula totais com `JOIN` e `SUM`.

## API do backend

- `GET/POST /api/jogos`, `GET/PUT/DELETE /api/jogos/:id`
- `GET /api/jogos/rawg/:rawgId/exists`
- `GET /api/jogos/:id/sessoes`
- `GET/POST /api/sessoes`, `GET/DELETE /api/sessoes/:id`
- `GET /api/sessoes/minutos-no-dia` e `/api/sessoes/minutos-por-jogo`
- `GET/PUT /api/configuracoes/:chave`
- `GET /api/health`

## API externa

RAWG Video Games Database, `https://api.rawg.io/api`:

- `GET /games?search=termo` para a busca
- `GET /games?ordering=-added` para os mais populares
- `GET /games/{id}` para a descrição do jogo

As respostas JSON viram objetos `JogoCatalogo` (`JogoCatalogo.fromJson`). Erros
de rede, de chave e de limite de uso são tratados com mensagens próprias.

## Roteiro sugerido para a demonstração

1. Abertura e tela inicial vazia.
2. Tocar na engrenagem central, buscar um jogo (API) e pôr na fila.
3. Repetir com mais três ou quatro jogos; guardar um como desejado.
4. Em "O que jogar", trocar de estratégia e mexer no tempo livre para ver a
   fila se reordenar.
5. Abrir um jogo, começar a jogar e registrar uma sessão; mostrar o progresso
   e a previsão de término.
6. Tentar começar um quarto jogo com a bancada cheia (regra 2) e tentar zerar
   um jogo sem sessão (regra 4).
7. Zerar um jogo com nota; voltar ao início e ver o manômetro e o letreiro
   atualizados.
8. Em "Registros", mostrar tempo por gênero, conquistas e ajustes.

## Créditos

Dados e capas dos jogos: [RAWG](https://rawg.io). Fontes IM Fell English SC e
Crimson Text (SIL Open Font License) e Special Elite (Apache 2.0); as licenças
estão em `assets/fonts/`.
