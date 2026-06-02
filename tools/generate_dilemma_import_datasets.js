const fs = require("fs");
const path = require("path");

const outputDir = path.join(
  __dirname,
  "..",
  "DecisionKernelTests",
  "Resources",
  "SimilarityExperiment",
  "ImportDatasets"
);

const cases = [
  {
    id: "promotion-family",
    enTopic: "career and family time",
    ruTopic: "карьерного роста и семейного времени",
    enLeft: "accept the promotion",
    enRight: "keep the calmer role",
    ruLeft: "принять повышение",
    ruRight: "остаться на спокойной должности",
    enLeftTitle: "Accept the promotion",
    enRightTitle: "Keep the calmer role",
    ruLeftTitle: "Принять повышение",
    ruRightTitle: "Остаться на спокойной должности",
    enLeftOutcome: "a stronger career path",
    enRightStake: "evenings with my family",
    ruLeftOutcome: "более сильную карьерную траекторию",
    ruRightStake: "вечера с семьей",
  },
  {
    id: "art-residency-partner",
    enTopic: "creative residency and relationship stability",
    ruTopic: "творческой резиденции и устойчивости отношений",
    enLeft: "take a three-month art residency",
    enRight: "stay home with my partner",
    ruLeft: "поехать на трехмесячную творческую резиденцию",
    ruRight: "остаться дома с партнером",
    enLeftTitle: "Take the residency",
    enRightTitle: "Stay home",
    ruLeftTitle: "Поехать на резиденцию",
    ruRightTitle: "Остаться дома",
    enLeftOutcome: "a rare creative breakthrough",
    enRightStake: "the daily rhythm of my relationship",
    ruLeftOutcome: "редкий творческий прорыв",
    ruRightStake: "повседневный ритм отношений",
  },
  {
    id: "graduate-school-parents",
    enTopic: "graduate school and care for parents",
    ruTopic: "магистратуры и помощи родителям",
    enLeft: "move abroad for graduate school",
    enRight: "study locally and stay near my parents",
    ruLeft: "уехать за границу в магистратуру",
    ruRight: "учиться рядом с родителями",
    enLeftTitle: "Move abroad",
    enRightTitle: "Study locally",
    ruLeftTitle: "Уехать за границу",
    ruRightTitle: "Учиться рядом",
    enLeftOutcome: "better academic opportunities",
    enRightStake: "my parents' practical support",
    ruLeftOutcome: "лучшие академические возможности",
    ruRightStake: "практическую поддержку родителей",
  },
  {
    id: "sports-team-weekends",
    enTopic: "competitive sports and weekend family life",
    ruTopic: "спортивной команды и семейных выходных",
    enLeft: "join a competitive sports team",
    enRight: "keep weekends free for family",
    ruLeft: "войти в соревновательную спортивную команду",
    ruRight: "оставить выходные свободными для семьи",
    enLeftTitle: "Join the team",
    enRightTitle: "Keep weekends free",
    ruLeftTitle: "Войти в команду",
    ruRightTitle: "Сохранить свободные выходные",
    enLeftOutcome: "visible athletic progress",
    enRightStake: "shared weekend routines",
    ruLeftOutcome: "заметный спортивный прогресс",
    ruRightStake: "общие семейные выходные",
  },
  {
    id: "startup-friends",
    enTopic: "startup work and friendships",
    ruTopic: "стартапа и дружеских связей",
    enLeft: "join a demanding startup",
    enRight: "keep my predictable job and social life",
    ruLeft: "перейти в требовательный стартап",
    ruRight: "сохранить предсказуемую работу и общение",
    enLeftTitle: "Join the startup",
    enRightTitle: "Keep the predictable job",
    ruLeftTitle: "Перейти в стартап",
    ruRightTitle: "Сохранить предсказуемую работу",
    enLeftOutcome: "ownership and faster learning",
    enRightStake: "friendships that need regular attention",
    ruLeftOutcome: "ответственность и быстрое обучение",
    ruRightStake: "дружбу, которой нужно регулярное внимание",
  },
  {
    id: "city-move-hometown",
    enTopic: "relocation and hometown belonging",
    ruTopic: "переезда и привязанности к родному городу",
    enLeft: "move to a larger city for opportunity",
    enRight: "stay in my hometown community",
    ruLeft: "переехать в большой город ради возможностей",
    ruRight: "остаться в родном городе",
    enLeftTitle: "Move to the larger city",
    enRightTitle: "Stay in the hometown",
    ruLeftTitle: "Переехать в большой город",
    ruRightTitle: "Остаться в родном городе",
    enLeftOutcome: "a wider professional network",
    enRightStake: "the community that knows me well",
    ruLeftOutcome: "более широкую профессиональную сеть",
    ruRightStake: "сообщество, которое хорошо меня знает",
  },
  {
    id: "ngo-leadership-care",
    enTopic: "public leadership and private caregiving",
    ruTopic: "публичного лидерства и личной заботы",
    enLeft: "lead a visible nonprofit campaign",
    enRight: "keep time for private caregiving",
    ruLeft: "возглавить заметную некоммерческую кампанию",
    ruRight: "сохранить время для личной заботы",
    enLeftTitle: "Lead the campaign",
    enRightTitle: "Keep caregiving time",
    ruLeftTitle: "Возглавить кампанию",
    ruRightTitle: "Сохранить время для заботы",
    enLeftOutcome: "public influence and leadership practice",
    enRightStake: "care that depends on my presence",
    ruLeftOutcome: "публичное влияние и практику лидерства",
    ruRightStake: "заботу, которая зависит от моего присутствия",
  },
  {
    id: "book-deadline-children",
    enTopic: "book deadline and time with children",
    ruTopic: "книжного дедлайна и времени с детьми",
    enLeft: "commit to an intense book deadline",
    enRight: "slow the project and be present with my children",
    ruLeft: "взять жесткий дедлайн по книге",
    ruRight: "замедлить проект и быть рядом с детьми",
    enLeftTitle: "Commit to the deadline",
    enRightTitle: "Slow the project",
    ruLeftTitle: "Взять жесткий дедлайн",
    ruRightTitle: "Замедлить проект",
    enLeftOutcome: "a finished manuscript and public momentum",
    enRightStake: "ordinary evenings with my children",
    ruLeftOutcome: "готовую рукопись и публичный импульс",
    ruRightStake: "обычные вечера с детьми",
  },
  {
    id: "public-debate-private-life",
    enTopic: "public debate and private peace",
    ruTopic: "публичной дискуссии и личного покоя",
    enLeft: "enter a public debate on an important issue",
    enRight: "stay private and protect home peace",
    ruLeft: "вступить в публичную дискуссию по важной теме",
    ruRight: "остаться в стороне и сохранить домашний покой",
    enLeftTitle: "Enter the debate",
    enRightTitle: "Stay private",
    ruLeftTitle: "Вступить в дискуссию",
    ruRightTitle: "Остаться в стороне",
    enLeftOutcome: "recognition as a serious voice",
    enRightStake: "privacy and emotional calm at home",
    ruLeftOutcome: "признание моего голоса",
    ruRightStake: "приватность и эмоциональный покой дома",
  },
  {
    id: "elite-school-neighborhood",
    enTopic: "elite education and neighborhood roots",
    ruTopic: "элитного образования и связи с районом",
    enLeft: "send my child to an elite school far away",
    enRight: "choose the local school near our community",
    ruLeft: "отдать ребенка в элитную школу далеко от дома",
    ruRight: "выбрать местную школу рядом с сообществом",
    enLeftTitle: "Choose the elite school",
    enRightTitle: "Choose the local school",
    ruLeftTitle: "Выбрать элитную школу",
    ruRightTitle: "Выбрать местную школу",
    enLeftOutcome: "stronger academic credentials",
    enRightStake: "neighborhood friendships and roots",
    ruLeftOutcome: "более сильные академические возможности",
    ruRightStake: "дружбу и связь с районом",
  },
];

const blocks = [
  {
    id: "ambition_vs_belonging",
    enTitle: "Ambition and growth vs closeness and stability",
    ruTitle: "Амбиции и рост vs близость и стабильность",
    enComment:
      "Same conflict structure: choose a path with higher status, growth, or achievement, or protect relationships, home routines, and belonging. Topics are intentionally different so lexical overlap is weak.",
    ruComment:
      "Одинаковая структура конфликта: выбрать путь с ростом, статусом или достижением либо защитить отношения, домашний ритм и чувство принадлежности. Темы намеренно разные, чтобы слабее работало совпадение слов.",
    enIntent:
      "A good conflict-based method should group these together even when the surface topic changes.",
    ruIntent:
      "Хороший conflict-based метод должен сближать эти дилеммы даже при разных поверхностных темах.",
    en: {
      leftValue: "growth, status, and a stronger role",
      leftSignal: "ambition is worth the cost",
      rightValue: "closeness, stable routines, and relationships",
      leftCost3: "It could make the relational option harder to protect.",
      rightCost3: "It may feel like avoiding a meaningful chance to grow.",
    },
    ru: {
      leftValue: "рост, статус и более сильную роль",
      leftSignal: "амбиции стоят своей цены",
      rightValue: "близость, устойчивый ритм и отношения",
      leftCost3: "Так будет труднее защитить сторону отношений.",
      rightCost3: "Может появиться ощущение, что я избегаю важного шанса вырасти.",
    },
    items: cases,
  },
  {
    id: "security_vs_care",
    enTitle: "Personal security vs care and generosity",
    ruTitle: "Личная безопасность vs забота и щедрость",
    enComment:
      "Each dilemma asks whether to preserve money, time, or capacity for oneself or spend it to support another person or group. The topics range from family to pets to community projects.",
    ruComment:
      "Каждая дилемма спрашивает, сохранять ли деньги, время или ресурс для себя либо потратить их на поддержку другого человека или группы. Темы идут от семьи до животных и городских проектов.",
    enIntent:
      "This block tests whether the model sees the care-vs-self-protection tradeoff across unrelated domains.",
    ruIntent:
      "Блок проверяет, видит ли модель tradeoff заботы и самозащиты в несвязанных доменах.",
    en: {
      leftValue: "care, generosity, and responsibility for others",
      leftSignal: "helping now matters more than keeping a reserve",
      rightValue: "personal security, reserves, and future independence",
      leftCost3: "It could leave me exposed if my own situation worsens.",
      rightCost3: "It may feel like protecting myself at someone else's expense.",
    },
    ru: {
      leftValue: "заботу, щедрость и ответственность за других",
      leftSignal: "помощь сейчас важнее сохранения запаса",
      rightValue: "личную безопасность, запас и будущую независимость",
      leftCost3: "Я могу остаться уязвимым, если моя ситуация ухудшится.",
      rightCost3: "Может казаться, что я защищаю себя за счет другого.",
    },
    items: [
      item("sibling-loan", "lend savings to my sibling", "keep the emergency fund", "дать брату или сестре деньги в долг", "сохранить резерв", "Lend the savings", "Keep the emergency fund", "Дать деньги в долг", "Сохранить резерв", "family debt", "семейного долга", "real relief for a close relative", "my rent and emergency buffer", "реальное облегчение близкому человеку", "аренду и резерв на случай кризиса"),
      item("charity-bonus", "donate my annual bonus to a local shelter", "save it for my own medical costs", "пожертвовать годовой бонус приюту", "сохранить его на свои медицинские расходы", "Donate the bonus", "Save the bonus", "Пожертвовать бонус", "Сохранить бонус", "charity giving", "благотворительности", "warm beds and meals for people nearby", "my future treatment costs", "теплые места и еду для людей рядом", "будущие расходы на лечение"),
      item("friend-hosting", "host a friend for several months", "keep my small apartment private", "пустить друга пожить на несколько месяцев", "сохранить приватность маленькой квартиры", "Host the friend", "Keep the apartment private", "Пустить друга", "Сохранить приватность", "housing help", "жилищной помощи", "safe temporary housing for a friend", "my sleep and personal space", "временное безопасное жилье для друга", "сон и личное пространство"),
      item("coworker-shift", "cover a coworker's difficult shifts", "protect my own recovery time", "закрыть тяжелые смены коллеги", "сохранить время на восстановление", "Cover the shifts", "Protect recovery time", "Закрыть смены", "Сохранить восстановление", "work scheduling", "рабочего расписания", "practical help during a crisis", "my energy and weekend plans", "практическую помощь в кризис", "энергию и планы на выходные"),
      item("community-budget", "spend the building budget on a neighbor's accessibility ramp", "keep it for repairs that may affect my flat", "потратить бюджет дома на пандус для соседа", "сохранить его на ремонт моей квартиры", "Fund the ramp", "Keep the repair reserve", "Профинансировать пандус", "Сохранить резерв на ремонт", "building maintenance", "домового бюджета", "mobility and dignity for a neighbor", "repairs that might affect me", "мобильность и достоинство соседа", "ремонт, который может коснуться меня"),
      item("pet-surgery", "pay for surgery for a stray dog I found", "keep the money for my own debt payment", "оплатить операцию найденной собаке", "оставить деньги на выплату своего долга", "Pay for surgery", "Pay my debt", "Оплатить операцию", "Заплатить по долгу", "animal rescue", "помощи животным", "a chance to save a vulnerable life", "my debt plan", "шанс спасти уязвимую жизнь", "мой план выплаты долга"),
      item("student-fees", "pay a student's exam fee", "save for my professional certification", "оплатить студенту экзаменационный взнос", "копить на свою сертификацию", "Pay the exam fee", "Save for certification", "Оплатить взнос", "Копить на сертификацию", "education support", "образовательной помощи", "access to an important exam", "my own credential", "доступ к важному экзамену", "мою собственную квалификацию"),
      item("family-trip-ticket", "buy a ticket so my cousin can attend a funeral", "keep the travel money for my vacation", "купить билет кузену на похороны", "оставить деньги на свой отпуск", "Buy the ticket", "Keep vacation money", "Купить билет", "Оставить деньги на отпуск", "urgent travel", "срочной поездки", "family presence at a painful moment", "my planned rest", "присутствие семьи в тяжелый момент", "запланированный отдых"),
      item("tools-neighbor", "lend expensive tools to a neighbor", "avoid risking damage to them", "одолжить дорогие инструменты соседу", "не рисковать их поломкой", "Lend the tools", "Protect the tools", "Одолжить инструменты", "Сберечь инструменты", "shared equipment", "общих инструментов", "trust and useful help nearby", "equipment I rely on", "доверие и полезную помощь рядом", "инструменты, на которые я рассчитываю"),
      item("volunteer-time", "give my only free day to a food bank", "use it to handle my own paperwork", "отдать единственный свободный день фудбанку", "заняться своими документами", "Volunteer at the food bank", "Handle my paperwork", "Помочь в фудбанке", "Заняться документами", "volunteering", "волонтерства", "meals for people under pressure", "my overdue personal tasks", "еду для людей в трудной ситуации", "мои просроченные личные дела"),
    ],
  },
  block(
    "health_vs_duty",
    "Health and recovery vs duty and productivity",
    "Здоровье и восстановление vs долг и продуктивность",
    "These dilemmas all ask whether to stop and recover or keep performing for a deadline, team, family, or cause.",
    "Все дилеммы спрашивают, остановиться и восстановиться или продолжать выполнять обязательство перед дедлайном, командой, семьей или делом.",
    "The topics differ, but the conflict is bodily and emotional limits versus obligation.",
    "Темы разные, но конфликт один: телесные и эмоциональные границы против обязательства.",
    "health, recovery, and sustainable energy",
    "rest is a real responsibility",
    "duty, productivity, and being counted on",
    "It may disappoint people who expected me to keep going.",
    "It may push my body or mind past a healthy limit.",
    "здоровье, восстановление и устойчивую энергию",
    "отдых тоже является ответственностью",
    "долг, продуктивность и надежность для других",
    "Это может разочаровать людей, которые ждали, что я продолжу.",
    "Это может перегрузить тело или психику.",
    [
      item("sick-leave-project", "take sick leave", "keep working on the project", "взять больничный", "продолжить работу над проектом", "Take sick leave", "Keep working", "Взять больничный", "Продолжить работу", "work illness", "болезни и работы", "time to recover properly", "the project deadline", "время нормально восстановиться", "проектный дедлайн"),
      item("sleep-exam", "sleep before the exam", "study all night", "выспаться перед экзаменом", "учить всю ночь", "Sleep before the exam", "Study all night", "Выспаться", "Учить всю ночь", "exam preparation", "подготовки к экзамену", "a clearer mind in the morning", "the chance to review more material", "более ясную голову утром", "шанс повторить больше материала"),
      item("injury-marathon", "skip the marathon because of an injury", "run anyway for the result", "пропустить марафон из-за травмы", "бежать ради результата", "Skip the marathon", "Run anyway", "Пропустить марафон", "Бежать несмотря на травму", "sports injury", "спортивной травмы", "a safer long-term recovery", "the goal I trained for", "более безопасное восстановление", "цель, к которой я готовился"),
      item("burnout-volunteering", "pause volunteering while burned out", "show up for the community shift", "поставить волонтерство на паузу из-за выгорания", "прийти на общественную смену", "Pause volunteering", "Show up for the shift", "Поставить волонтерство на паузу", "Прийти на смену", "volunteer burnout", "волонтерского выгорания", "space to regain emotional balance", "people who count on the shift", "пространство для восстановления баланса", "людей, которые рассчитывают на смену"),
      item("anxiety-presentation", "ask to postpone a presentation", "give it despite anxiety", "попросить перенести презентацию", "выступить несмотря на тревогу", "Postpone the presentation", "Give the presentation", "Перенести презентацию", "Выступить", "public speaking anxiety", "тревоги перед выступлением", "a calmer and safer delivery", "my reputation for reliability", "более спокойное и безопасное выступление", "репутацию надежного человека"),
      item("parent-rest-party", "rest after a hard parenting week", "organize the promised birthday party", "отдохнуть после тяжелой недели с ребенком", "организовать обещанный день рождения", "Rest this weekend", "Organize the party", "Отдохнуть на выходных", "Организовать праздник", "parenting fatigue", "родительской усталости", "needed energy for the next week", "a promise to my child", "нужную энергию на следующую неделю", "обещание ребенку"),
      item("doctor-client", "go to a medical appointment", "attend the client meeting", "пойти к врачу", "прийти на встречу с клиентом", "Go to the appointment", "Attend the client meeting", "Пойти к врачу", "Прийти к клиенту", "medical appointment", "приема у врача", "early attention to a health concern", "a valuable client relationship", "раннее внимание к здоровью", "важные отношения с клиентом"),
      item("digital-detox-chat", "turn off work chat for the weekend", "stay reachable for the team", "выключить рабочий чат на выходные", "оставаться доступным для команды", "Turn off work chat", "Stay reachable", "Выключить рабочий чат", "Оставаться доступным", "digital boundaries", "цифровых границ", "a real mental break", "team coordination", "настоящую ментальную паузу", "координацию команды"),
      item("therapy-household", "go to therapy after work", "finish urgent household tasks", "пойти на терапию после работы", "закончить срочные домашние дела", "Go to therapy", "Finish household tasks", "Пойти на терапию", "Закончить домашние дела", "therapy and chores", "терапии и быта", "attention to a recurring emotional pattern", "the household backlog", "внимание к повторяющемуся эмоциональному паттерну", "накопившиеся домашние задачи"),
      item("activism-break", "take a break from activism", "keep campaigning before the vote", "взять паузу в активизме", "продолжать кампанию перед голосованием", "Take a break", "Keep campaigning", "Взять паузу", "Продолжать кампанию", "activism fatigue", "усталости от активизма", "protection from long-term burnout", "the campaign's final push", "защиту от долгого выгорания", "финальный рывок кампании"),
    ]
  ),
  block(
    "freedom_vs_safety",
    "Freedom and adventure vs safety and predictability",
    "Свобода и приключение vs безопасность и предсказуемость",
    "Every case contrasts a freer, more open-ended choice with a safer, more controlled alternative.",
    "В каждом кейсе свободный и более открытый вариант противопоставлен безопасной и контролируемой альтернативе.",
    "The same freedom-safety conflict appears in travel, work, money, lifestyle, and relationships.",
    "Один и тот же конфликт свободы и безопасности проявляется в поездках, работе, деньгах, образе жизни и отношениях.",
    "freedom, exploration, and self-directed experience",
    "life should leave room for discovery",
    "safety, predictability, and controlled risk",
    "It may expose me to risks I cannot fully predict.",
    "It may make life feel smaller than I want.",
    "свободу, исследование и самостоятельный опыт",
    "в жизни должно быть место открытию",
    "безопасность, предсказуемость и контролируемый риск",
    "Это может открыть риски, которые я не полностью контролирую.",
    "Жизнь может стать меньше, чем мне хочется.",
    [
      item("solo-travel", "travel alone without a strict plan", "book a safe group tour", "поехать одному без жесткого плана", "выбрать безопасный групповой тур", "Travel alone", "Book the group tour", "Поехать одному", "Выбрать групповой тур", "solo travel", "самостоятельного путешествия", "a vivid sense of independence", "basic travel safety", "яркое чувство самостоятельности", "базовую безопасность в поездке"),
      item("freelance-job", "leave my job for freelance work", "stay with a stable employer", "уйти с работы во фриланс", "остаться у стабильного работодателя", "Go freelance", "Stay employed", "Уйти во фриланс", "Остаться в найме", "work format", "формата работы", "control over my schedule", "steady income", "контроль над своим графиком", "стабильный доход"),
      item("motorcycle", "buy a motorcycle", "keep using public transport", "купить мотоцикл", "продолжить ездить на общественном транспорте", "Buy the motorcycle", "Use public transport", "Купить мотоцикл", "Ездить на транспорте", "transport choice", "выбора транспорта", "a stronger feeling of movement and autonomy", "everyday safety", "более сильное чувство движения и автономии", "повседневную безопасность"),
      item("open-ended-date", "date someone very different from my usual type", "choose a more familiar match", "встречаться с человеком совсем не моего типа", "выбрать более привычного партнера", "Date the unusual match", "Choose the familiar match", "Встречаться с необычным человеком", "Выбрать привычного партнера", "dating", "отношений", "a surprising emotional experience", "predictable compatibility", "неожиданный эмоциональный опыт", "предсказуемую совместимость"),
      item("risky-investment", "invest a small sum in a risky idea", "keep it in a conservative account", "вложить небольшую сумму в рискованную идею", "оставить ее на консервативном счете", "Invest in the idea", "Keep the safe account", "Вложиться в идею", "Оставить на счете", "investment risk", "инвестиционного риска", "participation in a bold opportunity", "capital protection", "участие в смелой возможности", "сохранность капитала"),
      item("move-abroad", "move abroad without a guaranteed job", "wait until everything is arranged", "переехать за границу без гарантированной работы", "ждать, пока все будет устроено", "Move now", "Wait for certainty", "Переехать сейчас", "Ждать определенности", "relocation uncertainty", "неопределенного переезда", "a real reset of my life", "basic financial safety", "настоящую перезагрузку жизни", "базовую финансовую безопасность"),
      item("wild-hike", "go on a remote mountain hike", "choose an easy marked route", "пойти в удаленный горный поход", "выбрать простой размеченный маршрут", "Take the remote hike", "Choose the marked route", "Пойти в удаленный поход", "Выбрать размеченный маршрут", "outdoor adventure", "похода", "a stronger encounter with nature", "route control and lower danger", "более сильную встречу с природой", "контроль маршрута и меньшую опасность"),
      item("improv-show", "perform an improvised show", "prepare a scripted performance", "выступить с импровизацией", "подготовить прописанное выступление", "Perform improvised", "Use a script", "Импровизировать", "Выступить по сценарию", "performance art", "выступления", "creative aliveness in the moment", "a reliable result", "живое творчество в моменте", "надежный результат"),
      item("off-grid-month", "try living off-grid for a month", "rent a normal apartment", "пожить месяц автономно за городом", "снять обычную квартиру", "Live off-grid", "Rent normally", "Пожить автономно", "Снять обычную квартиру", "housing experiment", "жилищного эксперимента", "a test of independence", "comfort and infrastructure", "проверку самостоятельности", "комфорт и инфраструктуру"),
      item("quit-routine", "take a gap month with no fixed schedule", "keep my usual routine", "взять месяц паузы без расписания", "сохранить привычный режим", "Take the gap month", "Keep the routine", "Взять месяц паузы", "Сохранить режим", "life routine", "жизненного режима", "room to rediscover what I want", "daily structure", "пространство заново понять желания", "ежедневную структуру"),
    ]
  ),
  block(
    "truth_vs_loyalty",
    "Truth and principle vs loyalty and harmony",
    "Правда и принцип vs лояльность и гармония",
    "These cases ask whether to reveal an uncomfortable truth or protect a relationship, team, or group from conflict.",
    "Эти кейсы спрашивают, раскрывать ли неудобную правду или защитить отношения, команду или группу от конфликта.",
    "The topics differ, but the core structure is transparency against loyalty.",
    "Темы разные, но структура одна: прозрачность против лояльности.",
    "truth, accountability, and principled transparency",
    "clarity should not be sacrificed for comfort",
    "loyalty, harmony, and protection of relationships",
    "It may damage trust with people close to the situation.",
    "It may leave an important truth hidden.",
    "правду, ответственность и принципиальную прозрачность",
    "ясность не стоит приносить в жертву комфорту",
    "лояльность, гармонию и защиту отношений",
    "Это может повредить доверию людей, близких к ситуации.",
    "Важная правда может остаться скрытой.",
    [
      item("coworker-error", "tell my manager about a coworker's serious mistake", "handle it quietly with the coworker", "рассказать руководителю о серьезной ошибке коллеги", "решить это тихо с коллегой", "Tell the manager", "Handle it quietly", "Рассказать руководителю", "Решить тихо", "work mistake", "рабочей ошибки", "a clearer record of what happened", "my relationship with the coworker", "более ясную картину произошедшего", "отношения с коллегой"),
      item("friend-partner", "tell a friend what I heard about their partner", "stay out of their relationship", "рассказать другу то, что я услышал о его партнере", "не вмешиваться в отношения", "Tell the friend", "Stay out of it", "Рассказать другу", "Не вмешиваться", "friendship and romance", "дружбы и отношений", "honest information before a major choice", "the peace of the friendship", "честную информацию перед важным выбором", "спокойствие дружбы"),
      item("family-secret", "reveal a family secret before a wedding", "keep the secret to avoid hurting everyone", "раскрыть семейный секрет перед свадьбой", "сохранить секрет, чтобы никого не ранить", "Reveal the secret", "Keep the secret", "Раскрыть секрет", "Сохранить секрет", "family secret", "семейного секрета", "a decision based on reality", "family peace before the wedding", "решение на основе реальности", "семейный мир перед свадьбой"),
      item("restaurant-review", "write an honest negative review of a friend's restaurant", "stay silent to support them", "написать честный негативный отзыв о ресторане друга", "промолчать, чтобы поддержать его", "Write the review", "Stay silent", "Написать отзыв", "Промолчать", "public review", "публичного отзыва", "useful honesty for customers", "a friend's fragile business", "полезную честность для клиентов", "хрупкий бизнес друга"),
      item("plagiarism", "report plagiarism in a class project", "protect the group grade", "сообщить о плагиате в учебном проекте", "защитить оценку группы", "Report plagiarism", "Protect the grade", "Сообщить о плагиате", "Защитить оценку", "academic integrity", "академической честности", "fairness in the evaluation", "group solidarity", "справедливость оценки", "солидарность группы"),
      item("product-bug", "disclose a product bug before launch", "avoid delaying the release", "раскрыть баг продукта перед запуском", "не задерживать релиз", "Disclose the bug", "Avoid the delay", "Раскрыть баг", "Не задерживать релиз", "product launch", "запуска продукта", "accountability to users", "the team's launch momentum", "ответственность перед пользователями", "импульс команды перед релизом"),
      item("team-cheating", "tell the coach that a teammate cheated", "protect the team's win", "сказать тренеру, что товарищ по команде жульничал", "защитить победу команды", "Tell the coach", "Protect the win", "Сказать тренеру", "Защитить победу", "sports fairness", "спортивной честности", "a fair result", "team unity after the match", "честный результат", "единство команды после матча"),
      item("landlord-defect", "tell future tenants about a hidden defect", "avoid conflict with the landlord", "рассказать будущим жильцам о скрытом дефекте", "избежать конфликта с арендодателем", "Warn the tenants", "Avoid landlord conflict", "Предупредить жильцов", "Избежать конфликта", "rental housing", "аренды жилья", "protection for the next tenants", "my current housing relationship", "защиту будущих жильцов", "мои текущие отношения по жилью"),
      item("medical-mistake", "ask openly about a possible medical mistake", "avoid challenging the doctor", "открыто спросить о возможной медицинской ошибке", "не спорить с врачом", "Ask openly", "Avoid challenging the doctor", "Спросить открыто", "Не спорить с врачом", "medical trust", "медицинского доверия", "clarity about health decisions", "a cooperative tone with the doctor", "ясность медицинских решений", "спокойный контакт с врачом"),
      item("public-correction", "correct a respected elder in public", "let the mistake pass to preserve respect", "поправить уважаемого старшего публично", "промолчать ради уважения", "Correct publicly", "Let it pass", "Поправить публично", "Промолчать", "public disagreement", "публичного несогласия", "accuracy for everyone listening", "respectful social order", "точность для всех слушателей", "уважительный социальный порядок"),
    ]
  ),
  block(
    "discipline_vs_comfort",
    "Long-term discipline vs short-term comfort",
    "Долгосрочная дисциплина vs краткосрочный комфорт",
    "Every dilemma asks whether to do something effortful for a future benefit or choose immediate ease and relief.",
    "Каждая дилемма спрашивает, делать ли усилие ради будущей пользы или выбрать немедленное облегчение.",
    "This block should cluster across language learning, health, money, craft, and household habits.",
    "Блок должен сближаться через изучение языка, здоровье, деньги, ремесло и бытовые привычки.",
    "discipline, mastery, and long-term self-respect",
    "future progress needs repeated effort",
    "comfort, ease, and immediate relief",
    "It will demand energy when comfort is available.",
    "It may leave the long-term goal underdeveloped.",
    "дисциплину, мастерство и долгосрочное самоуважение",
    "будущий прогресс требует повторяющегося усилия",
    "комфорт, легкость и немедленное облегчение",
    "Это потребует энергии, когда доступен комфорт.",
    "Долгосрочная цель может остаться недоразвитой.",
    [
      item("language-evenings", "study a language every evening", "relax after work", "учить язык каждый вечер", "отдыхать после работы", "Study the language", "Relax after work", "Учить язык", "Отдыхать после работы", "language learning", "изучения языка", "steady fluency over time", "my evening comfort", "постепенную беглость", "вечерний комфорт"),
      item("morning-training", "wake early for fitness training", "sleep longer", "вставать рано на тренировки", "спать дольше", "Train in the morning", "Sleep longer", "Тренироваться утром", "Спать дольше", "fitness routine", "спортивной привычки", "a stronger body and routine", "easy mornings", "более сильное тело и режим", "легкое утро"),
      item("budget-tracking", "track every expense this month", "spend without strict monitoring", "записывать все расходы в этом месяце", "тратить без строгого контроля", "Track expenses", "Spend freely", "Записывать расходы", "Тратить свободно", "personal budget", "личного бюджета", "control over my money patterns", "spontaneous small pleasures", "контроль над денежными привычками", "спонтанные маленькие удовольствия"),
      item("sleep-schedule", "keep a strict sleep schedule", "stay up for entertainment", "держать строгий режим сна", "засиживаться ради развлечений", "Keep the sleep schedule", "Stay up late", "Держать режим сна", "Засиживаться", "sleep hygiene", "режима сна", "better energy in the long run", "late-night fun", "больше энергии в долгую", "ночные развлечения"),
      item("meditation", "meditate daily for three months", "skip it when I feel busy", "медитировать каждый день три месяца", "пропускать, когда я занят", "Meditate daily", "Skip when busy", "Медитировать ежедневно", "Пропускать при занятости", "mental practice", "ментальной практики", "more stable attention", "a lighter daily schedule", "более устойчивое внимание", "более легкий дневной график"),
      item("music-practice", "practice piano scales every day", "only play when it feels fun", "каждый день играть гаммы на пианино", "играть только когда весело", "Practice scales", "Play for fun", "Играть гаммы", "Играть для удовольствия", "music practice", "музыкальной практики", "real technical growth", "playful enjoyment", "настоящий технический рост", "легкое удовольствие"),
      item("coding-project", "finish a coding side project", "watch shows in the evening", "закончить pet-проект по программированию", "смотреть сериалы вечером", "Finish the project", "Watch shows", "Закончить проект", "Смотреть сериалы", "coding project", "pet-проекта", "a portfolio piece", "passive rest after work", "работу для портфолио", "пассивный отдых после работы"),
      item("meal-planning", "cook planned meals for the week", "order food whenever I want", "готовить еду на неделю", "заказывать еду когда хочется", "Cook planned meals", "Order food freely", "Готовить на неделю", "Заказывать еду", "meal planning", "планирования еды", "better health and spending control", "convenient food choices", "здоровье и контроль расходов", "удобный выбор еды"),
      item("declutter", "declutter the apartment every weekend", "ignore the mess and rest", "разбирать квартиру каждые выходные", "игнорировать беспорядок и отдыхать", "Declutter weekly", "Ignore the mess", "Разбирать квартиру", "Игнорировать беспорядок", "home organization", "порядка дома", "a calmer living space", "rest without chores", "более спокойное пространство", "отдых без домашних дел"),
      item("reading-plan", "follow a difficult reading plan", "read only light articles", "следовать сложному плану чтения", "читать только легкие статьи", "Follow the reading plan", "Read light articles", "Следовать плану чтения", "Читать легкое", "intellectual habit", "интеллектуальной привычки", "deeper understanding over time", "easy mental entertainment", "более глубокое понимание", "легкое умственное развлечение"),
    ]
  ),
  block(
    "autonomy_vs_approval",
    "Self-direction vs approval and expectations",
    "Самостоятельность vs одобрение и ожидания",
    "These dilemmas all ask whether to choose according to personal values or meet family, cultural, or peer expectations.",
    "Все дилеммы спрашивают, выбирать ли по своим ценностям или соответствовать ожиданиям семьи, культуры или окружения.",
    "The block tests identity-level similarity across unrelated life domains.",
    "Блок проверяет сходство на уровне идентичности в разных жизненных сферах.",
    "autonomy, self-definition, and personal fit",
    "my life should be recognizably mine",
    "approval, belonging, and social expectations",
    "It may create tension with people whose approval matters.",
    "It may make me feel like I am living someone else's script.",
    "автономию, самоопределение и личное соответствие",
    "моя жизнь должна быть узнаваемо моей",
    "одобрение, принадлежность и социальные ожидания",
    "Это может создать напряжение с людьми, чье одобрение важно.",
    "Может возникнуть чувство, что я живу по чужому сценарию.",
    [
      item("career-family-expectation", "choose a creative career", "take the respected corporate path my family prefers", "выбрать творческую карьеру", "пойти в уважаемую корпоративную сферу, как хочет семья", "Choose the creative career", "Take the corporate path", "Выбрать творческую карьеру", "Пойти в корпорацию", "career identity", "карьерной идентичности", "work that fits my inner motives", "family pride and approval", "работу, которая совпадает с внутренними мотивами", "гордость и одобрение семьи"),
      item("clothing-style", "dress in a style that feels like me", "dress conventionally for relatives", "одеваться в своем стиле", "одеваться привычно для родственников", "Dress my way", "Dress conventionally", "Одеваться по-своему", "Одеваться привычно", "personal style", "личного стиля", "visible self-expression", "smooth family gatherings", "видимое самовыражение", "спокойные семейные встречи"),
      item("small-wedding", "have a small wedding", "hold the large celebration expected by relatives", "устроить маленькую свадьбу", "провести большой праздник, которого ждут родственники", "Have a small wedding", "Hold the large wedding", "Устроить маленькую свадьбу", "Провести большой праздник", "wedding planning", "свадьбы", "an intimate ceremony that fits us", "relatives feeling honored", "камерную церемонию, которая нам подходит", "ощущение уважения у родственников"),
      item("religious-ritual", "skip a ritual I no longer believe in", "participate to please my family", "пропустить ритуал, в который я больше не верю", "участвовать ради семьи", "Skip the ritual", "Participate in the ritual", "Пропустить ритуал", "Участвовать в ритуале", "religious practice", "религиозной практики", "honesty about my beliefs", "family continuity", "честность о своих убеждениях", "семейную преемственность"),
      item("parenting-choice", "raise my child with my own rules", "follow relatives' parenting advice", "воспитывать ребенка по своим правилам", "следовать советам родственников", "Use my parenting rules", "Follow relatives' advice", "Воспитывать по-своему", "Следовать советам", "parenting norms", "воспитания", "a parenting style I trust", "less criticism from relatives", "стиль воспитания, которому я доверяю", "меньше критики от родственников"),
      item("social-media", "stop posting online", "keep posting because friends expect updates", "перестать публиковать в соцсетях", "продолжать постить, потому что друзья ждут новостей", "Stop posting", "Keep posting", "Перестать публиковать", "Продолжать постить", "online presence", "социальных сетей", "a quieter personal boundary", "social connection and visibility", "более спокойную личную границу", "социальную связь и видимость"),
      item("partner-choice", "date someone my family may not approve of", "choose a socially easier relationship", "встречаться с человеком, которого семья может не одобрить", "выбрать социально более простой вариант", "Date the person I choose", "Choose the easier match", "Встречаться с выбранным человеком", "Выбрать простой вариант", "relationship choice", "выбора партнера", "a relationship based on my own attraction", "social acceptance", "отношения на основе моего выбора", "социальное принятие"),
      item("study-subject", "study philosophy", "study finance because everyone says it is practical", "изучать философию", "изучать финансы, потому что это считают практичным", "Study philosophy", "Study finance", "Изучать философию", "Изучать финансы", "university major", "выбора специальности", "intellectual work that feels alive", "approval for a practical path", "живой интеллектуальный интерес", "одобрение практичного пути"),
      item("live-alone", "live alone in a modest studio", "share a family apartment as expected", "жить одному в скромной студии", "жить в семейной квартире, как ожидают", "Live alone", "Share the family apartment", "Жить одному", "Жить с семьей", "housing independence", "жилищной самостоятельности", "daily independence", "family closeness and approval", "ежедневную самостоятельность", "близость и одобрение семьи"),
      item("holiday-plan", "spend a holiday quietly by myself", "join the large family gathering", "провести праздник спокойно одному", "присоединиться к большой семейной встрече", "Spend it quietly", "Join the gathering", "Провести праздник тихо", "Прийти на встречу", "holiday expectations", "праздничных ожиданий", "a holiday that restores me", "family tradition and inclusion", "праздник, который меня восстанавливает", "семейную традицию и включенность"),
    ]
  ),
  block(
    "change_vs_tradition",
    "Change and innovation vs tradition and continuity",
    "Изменение и новизна vs традиция и преемственность",
    "Each case contrasts a redesign, new method, or modernization with preserving a trusted old way.",
    "Каждый кейс противопоставляет редизайн, новый метод или модернизацию сохранению проверенного старого способа.",
    "This block is designed to separate 'new vs old' conflict structure from the concrete domain.",
    "Блок отделяет структуру конфликта 'новое против старого' от конкретной темы.",
    "change, experimentation, and adaptation",
    "systems should evolve when the context changes",
    "tradition, continuity, and trusted practice",
    "It may break something people already trust.",
    "It may let the old way become stale or ineffective.",
    "изменение, эксперимент и адаптацию",
    "системы должны меняться, когда меняется контекст",
    "традицию, преемственность и проверенную практику",
    "Это может сломать то, чему люди уже доверяют.",
    "Старый способ может устареть или стать неэффективным.",
    [
      item("app-redesign", "redesign the app navigation", "keep the familiar interface", "переделать навигацию приложения", "оставить привычный интерфейс", "Redesign navigation", "Keep the interface", "Переделать навигацию", "Оставить интерфейс", "software design", "дизайна приложения", "a cleaner product for new users", "current users' familiarity", "более понятный продукт для новых пользователей", "привычку текущих пользователей"),
      item("family-recipe", "change a family recipe", "cook it exactly as my grandmother did", "изменить семейный рецепт", "готовить его точно как бабушка", "Change the recipe", "Keep the recipe", "Изменить рецепт", "Сохранить рецепт", "family cooking", "семейного рецепта", "a dish that fits current tastes", "family memory", "блюдо под современные вкусы", "семейную память"),
      item("school-curriculum", "introduce project-based classes", "keep the traditional lecture format", "ввести проектные занятия", "оставить традиционные лекции", "Introduce projects", "Keep lectures", "Ввести проекты", "Оставить лекции", "education method", "образовательного метода", "more active learning", "a proven teaching rhythm", "более активное обучение", "проверенный ритм преподавания"),
      item("shop-renovation", "renovate an old shop", "preserve its original look", "обновить старый магазин", "сохранить его исходный вид", "Renovate the shop", "Preserve the look", "Обновить магазин", "Сохранить вид", "small business design", "дизайна магазина", "a fresher customer experience", "the shop's local character", "более свежий опыт для клиентов", "местный характер магазина"),
      item("ceremony-format", "make a ceremony informal", "follow the formal tradition", "сделать церемонию неформальной", "следовать формальной традиции", "Make it informal", "Follow tradition", "Сделать неформально", "Следовать традиции", "ceremony planning", "формата церемонии", "a more honest shared mood", "the dignity of the ritual", "более честное общее настроение", "достоинство ритуала"),
      item("farming-method", "try regenerative farming methods", "keep the familiar conventional method", "попробовать регенеративные методы земледелия", "сохранить привычный метод", "Try new farming methods", "Keep the familiar method", "Попробовать новые методы", "Сохранить привычный метод", "farming", "земледелия", "learning that may improve the land", "predictable harvest routines", "обучение, которое может улучшить землю", "предсказуемый ритм урожая"),
      item("team-process", "replace weekly status meetings with async updates", "keep the old meeting routine", "заменить еженедельные встречи асинхронными обновлениями", "оставить старый ритм встреч", "Use async updates", "Keep meetings", "Перейти на асинхронные обновления", "Оставить встречи", "team process", "командного процесса", "less wasted coordination time", "a shared communication habit", "меньше потерянного времени на координацию", "общую привычку общения"),
      item("city-park", "redesign a historic park for accessibility", "preserve the original layout", "переделать исторический парк ради доступности", "сохранить исходную планировку", "Redesign the park", "Preserve the layout", "Переделать парк", "Сохранить планировку", "urban planning", "городского парка", "access for more residents", "historical continuity", "доступ для большего числа жителей", "историческую преемственность"),
      item("community-rules", "modernize the community group's rules", "keep the rules that founders wrote", "обновить правила сообщества", "сохранить правила основателей", "Modernize the rules", "Keep founder rules", "Обновить правила", "Сохранить правила основателей", "community governance", "управления сообществом", "fairness for current members", "respect for the founders", "справедливость для нынешних участников", "уважение к основателям"),
      item("newspaper-format", "move a local newspaper online-first", "keep the printed paper central", "сделать местную газету прежде всего цифровой", "оставить печатный формат главным", "Go online-first", "Keep print central", "Перейти в цифровой формат", "Оставить печать главной", "local media", "местной газеты", "reach among younger readers", "the ritual of the printed paper", "доступ к молодой аудитории", "ритуал печатной газеты"),
    ]
  ),
  block(
    "fairness_vs_mercy",
    "Fairness and rules vs mercy and context",
    "Справедливость и правила vs милосердие и контекст",
    "These cases ask whether to apply the same rule to everyone or make an exception because of someone's circumstances.",
    "Эти кейсы спрашивают, применять ли общее правило ко всем или сделать исключение из-за обстоятельств человека.",
    "The block should reveal whether similarity follows the normative conflict rather than the institution involved.",
    "Блок должен показать, идет ли similarity за нормативным конфликтом, а не за конкретным институтом.",
    "fairness, consistency, and equal rules",
    "rules lose meaning when they bend too easily",
    "mercy, context, and human exception",
    "It may feel cold toward a person under pressure.",
    "It may weaken trust that the rules are equal.",
    "справедливость, последовательность и равные правила",
    "правила теряют смысл, если их слишком легко сгибать",
    "милосердие, контекст и человеческое исключение",
    "Это может выглядеть холодно к человеку под давлением.",
    "Это может ослабить доверие к равенству правил.",
    [
      item("late-assignment", "enforce the late penalty", "accept the assignment because of a family emergency", "применить штраф за просрочку", "принять работу из-за семейной чрезвычайной ситуации", "Enforce the penalty", "Accept the assignment", "Применить штраф", "Принять работу", "school deadline", "учебного дедлайна", "a consistent grading standard", "the student's difficult week", "последовательный стандарт оценки", "сложную неделю студента"),
      item("employee-shift", "assign shifts by the written rotation", "change the schedule for one employee's childcare issue", "назначить смены по письменной очереди", "изменить график из-за проблемы с ребенком у сотрудника", "Use the rotation", "Make an exception", "Следовать очереди", "Сделать исключение", "work shifts", "рабочих смен", "predictability for the whole staff", "a parent's urgent constraint", "предсказуемость для всей команды", "срочное ограничение родителя"),
      item("rent-late", "charge the late rent fee", "waive it after a tenant's hospital stay", "начислить штраф за позднюю оплату аренды", "простить его после госпитализации жильца", "Charge the fee", "Waive the fee", "Начислить штраф", "Простить штраф", "rental payment", "арендной оплаты", "the lease terms staying clear", "the tenant's recovery", "ясность условий договора", "восстановление жильца"),
      item("competition-rule", "disqualify a contestant for missing a rule", "allow them to continue after a misunderstanding", "дисквалифицировать участника за нарушение правила", "позволить продолжить из-за недопонимания", "Disqualify the contestant", "Let them continue", "Дисквалифицировать", "Позволить продолжить", "competition rules", "правил конкурса", "respect for every other contestant", "an honest misunderstanding", "уважение ко всем участникам", "честное недопонимание"),
      item("child-chores", "apply the same chore rule to both children", "excuse one child after a hard school day", "применить одно правило домашних дел к обоим детям", "освободить одного после тяжелого учебного дня", "Apply the same rule", "Excuse one child", "Применить одно правило", "Освободить одного ребенка", "family chores", "домашних обязанностей", "clear expectations at home", "a child's emotional state", "ясные ожидания дома", "эмоциональное состояние ребенка"),
      item("parking-ticket", "pay the parking ticket", "appeal it because the sign was hidden", "оплатить штраф за парковку", "оспорить его из-за скрытого знака", "Pay the ticket", "Appeal the ticket", "Оплатить штраф", "Оспорить штраф", "parking fine", "парковочного штрафа", "acceptance of public rules", "a confusing situation", "принятие общественных правил", "запутанную ситуацию"),
      item("scholarship", "award a scholarship by score only", "consider the applicant's hardship", "дать стипендию только по баллам", "учесть трудные обстоятельства кандидата", "Use score only", "Consider hardship", "Смотреть только на баллы", "Учесть обстоятельства", "scholarship selection", "выбора стипендиата", "a transparent ranking", "barriers the applicant faced", "прозрачный рейтинг", "препятствия кандидата"),
      item("refund-policy", "deny a refund after the deadline", "refund someone who missed it during a crisis", "отказать в возврате после срока", "вернуть деньги человеку, который пропустил срок из-за кризиса", "Deny the refund", "Grant the refund", "Отказать в возврате", "Вернуть деньги", "refund policy", "политики возврата", "a policy that remains enforceable", "a customer's crisis", "политику, которую можно применять", "кризис клиента"),
      item("team-selection", "choose players strictly by trial scores", "include someone recovering from illness", "выбрать игроков строго по результатам отбора", "включить человека после болезни", "Use trial scores", "Include the recovering player", "Смотреть на результаты", "Включить игрока после болезни", "team selection", "отбора в команду", "merit-based selection", "the player's temporary setback", "отбор по заслугам", "временную неудачу игрока"),
      item("queue", "keep the queue order", "let an exhausted parent go first", "сохранить порядок очереди", "пропустить уставшего родителя вперед", "Keep queue order", "Let the parent go first", "Сохранить очередь", "Пропустить родителя", "public queue", "очереди", "respect for everyone waiting", "a visible human need", "уважение ко всем ожидающим", "видимую человеческую нужду"),
    ]
  ),
  block(
    "privacy_vs_openness",
    "Privacy and control vs openness and trust",
    "Приватность и контроль vs открытость и доверие",
    "Each case contrasts keeping information or space private with sharing it to build trust, connection, or accountability.",
    "Каждый кейс противопоставляет сохранение информации или пространства в приватности и раскрытие ради доверия, связи или ответственности.",
    "This block should group disclosure-boundary conflicts across health, money, relationships, work, and data.",
    "Блок должен группировать конфликты раскрытия и границ в здоровье, деньгах, отношениях, работе и данных.",
    "privacy, control, and personal boundaries",
    "not everything important must be shared",
    "openness, trust, and accountability",
    "It may make others feel excluded or suspicious.",
    "It may expose more of me than feels safe.",
    "приватность, контроль и личные границы",
    "не всем важным нужно делиться",
    "открытость, доверие и ответственность",
    "Другие могут почувствовать исключенность или подозрение.",
    "Я могу раскрыть больше, чем для меня безопасно.",
    [
      item("medical-info", "keep my diagnosis private", "tell my family what is happening", "сохранить диагноз в тайне", "рассказать семье, что происходит", "Keep it private", "Tell the family", "Сохранить в тайне", "Рассказать семье", "medical disclosure", "медицинского раскрытия", "control over a vulnerable fact", "family trust and support", "контроль над уязвимым фактом", "доверие и поддержку семьи"),
      item("salary", "keep my salary private", "share it with coworkers for pay transparency", "сохранить зарплату в тайне", "поделиться ей с коллегами ради прозрачности оплаты", "Keep salary private", "Share salary", "Сохранить зарплату в тайне", "Поделиться зарплатой", "salary transparency", "прозрачности зарплаты", "control over financial information", "fair pay conversations", "контроль над финансовой информацией", "разговоры о справедливой оплате"),
      item("journal", "keep my journal locked", "show parts of it to my partner", "держать дневник закрытым", "показать часть партнеру", "Keep the journal private", "Share parts of it", "Закрыть дневник", "Показать часть дневника", "personal journal", "личного дневника", "an inner space that is only mine", "deeper emotional closeness", "внутреннее пространство только для меня", "более глубокую эмоциональную близость"),
      item("relationship-boundary", "keep some friendships separate from my relationship", "introduce everyone to my partner", "сохранить часть дружбы отдельно от отношений", "познакомить всех с партнером", "Keep friendships separate", "Introduce everyone", "Сохранить дружбу отдельно", "Познакомить всех", "relationship boundaries", "границ в отношениях", "independent social space", "shared trust with my partner", "самостоятельное социальное пространство", "общее доверие с партнером"),
      item("location-sharing", "turn off location sharing", "keep it on for my family's peace of mind", "выключить передачу геолокации", "оставить ее ради спокойствия семьи", "Turn off location sharing", "Keep sharing location", "Выключить геолокацию", "Оставить геолокацию", "location tracking", "геолокации", "freedom from constant visibility", "family reassurance", "свободу от постоянной видимости", "спокойствие семьи"),
      item("product-data", "minimize user data collection", "collect more data to improve the product", "минимизировать сбор данных пользователей", "собирать больше данных для улучшения продукта", "Minimize data collection", "Collect more data", "Минимизировать сбор данных", "Собирать больше данных", "product analytics", "продуктовой аналитики", "stronger respect for users' boundaries", "product learning and accountability", "большее уважение границ пользователей", "обучение продукта и ответственность"),
      item("therapy-share", "keep therapy topics private", "tell a close friend what I am working through", "оставить темы терапии приватными", "рассказать близкому другу, с чем я работаю", "Keep therapy private", "Tell the friend", "Оставить терапию приватной", "Рассказать другу", "therapy disclosure", "раскрытия терапии", "protected emotional processing", "support from a trusted person", "защищенную эмоциональную работу", "поддержку доверенного человека"),
      item("office-calendar", "hide details on my work calendar", "make my calendar transparent to the team", "скрыть детали рабочего календаря", "сделать календарь прозрачным для команды", "Hide calendar details", "Share calendar details", "Скрыть детали календаря", "Открыть календарь", "work calendar", "рабочего календаря", "control over my attention", "better team coordination", "контроль над своим вниманием", "лучшую координацию команды"),
      item("family-finances", "keep my debt private", "tell my partner the full picture", "скрывать свой долг", "рассказать партнеру полную картину", "Keep debt private", "Tell the full picture", "Скрывать долг", "Рассказать полностью", "family finances", "семейных финансов", "time to handle shame privately", "honest shared planning", "время справиться со стыдом приватно", "честное совместное планирование"),
      item("anonymous-feedback", "give anonymous feedback", "sign my name for accountability", "дать анонимную обратную связь", "подписаться ради ответственности", "Give anonymous feedback", "Sign my name", "Дать анонимный отзыв", "Подписаться", "workplace feedback", "рабочей обратной связи", "protection from retaliation", "trust in the feedback process", "защиту от ответной реакции", "доверие к процессу обратной связи"),
    ]
  ),
  block(
    "quality_vs_speed",
    "Quality and craft vs speed and availability",
    "Качество и мастерство vs скорость и доступность",
    "Every dilemma asks whether to slow down for a better result or deliver sooner with more compromises.",
    "Каждая дилемма спрашивает, замедлиться ради лучшего результата или выдать быстрее с компромиссами.",
    "The block should connect craftsmanship tradeoffs across software, writing, food, repairs, events, and home projects.",
    "Блок должен связывать tradeoff мастерства в софте, письме, еде, ремонте, событиях и домашних проектах.",
    "quality, craft, and durable standards",
    "some work deserves enough time to be done well",
    "speed, availability, and timely delivery",
    "It may delay value that people need soon.",
    "It may create a result I do not fully trust.",
    "качество, мастерство и устойчивые стандарты",
    "некоторой работе нужно достаточно времени, чтобы быть сделанной хорошо",
    "скорость, доступность и своевременную поставку",
    "Это может задержать пользу, которая нужна людям скоро.",
    "Может получиться результат, которому я не полностью доверяю.",
    [
      item("app-release", "delay the app release for polish", "ship the basic version this week", "отложить релиз приложения ради полировки", "выпустить базовую версию на этой неделе", "Delay for polish", "Ship this week", "Отложить ради качества", "Выпустить на неделе", "software release", "релиза приложения", "a more reliable user experience", "early user access", "более надежный пользовательский опыт", "ранний доступ пользователей"),
      item("thesis", "rewrite my thesis chapter carefully", "submit the acceptable draft now", "тщательно переписать главу диплома", "сдать приемлемый черновик сейчас", "Rewrite carefully", "Submit now", "Переписать тщательно", "Сдать сейчас", "academic writing", "академического текста", "a clearer argument", "meeting the submission window", "более ясный аргумент", "попадание в окно сдачи"),
      item("dinner", "cook a proper dinner from scratch", "serve a quick simple meal", "приготовить полноценный ужин с нуля", "подать простой быстрый ужин", "Cook from scratch", "Serve quickly", "Готовить с нуля", "Подать быстро", "cooking for guests", "ужина для гостей", "a meal I am proud of", "hungry guests eating on time", "ужин, которым можно гордиться", "своевременную еду для голодных гостей"),
      item("bike-repair", "fully repair the bike before riding", "make a temporary fix and go", "полностью починить велосипед перед поездкой", "сделать временный ремонт и поехать", "Repair fully", "Use a temporary fix", "Починить полностью", "Сделать временно", "bike repair", "ремонта велосипеда", "confidence in the repair", "using the bike today", "уверенность в ремонте", "возможность ехать сегодня"),
      item("video-publish", "edit a video until it is strong", "publish a rough version while the topic is current", "монтировать видео до хорошего уровня", "выпустить черновую версию, пока тема актуальна", "Edit longer", "Publish rough", "Монтировать дольше", "Выпустить черновик", "video publishing", "публикации видео", "a stronger final piece", "relevance while the topic is fresh", "более сильную итоговую работу", "актуальность свежей темы"),
      item("work-report", "verify every number in a report", "send a quick estimate to unblock the team", "проверить каждую цифру в отчете", "отправить быструю оценку, чтобы разблокировать команду", "Verify every number", "Send the estimate", "Проверить все цифры", "Отправить оценку", "business report", "рабочего отчета", "trustworthy analysis", "team progress today", "надежный анализ", "прогресс команды сегодня"),
      item("event-plan", "plan the event in detail", "announce it now and adjust later", "подробно спланировать мероприятие", "объявить сейчас и донастроить позже", "Plan in detail", "Announce now", "Спланировать подробно", "Объявить сейчас", "event planning", "планирования мероприятия", "fewer surprises during the event", "time for people to register", "меньше сюрпризов на событии", "время людям записаться"),
      item("contract", "review the contract line by line", "sign the standard version to move quickly", "проверить договор построчно", "подписать стандартную версию ради скорости", "Review line by line", "Sign the standard version", "Проверить построчно", "Подписать стандартно", "contract review", "проверки договора", "fewer hidden obligations", "fast start of the deal", "меньше скрытых обязательств", "быстрый старт сделки"),
      item("painting", "finish the painting slowly", "submit the nearly finished piece", "медленно довести картину", "сдать почти готовую работу", "Finish slowly", "Submit nearly finished", "Довести медленно", "Сдать почти готовую", "visual art", "картины", "a complete artistic statement", "meeting the exhibition deadline", "полное художественное высказывание", "соблюдение срока выставки"),
      item("home-renovation", "redo the bathroom properly", "patch the visible problems before guests arrive", "нормально переделать ванную", "замазать видимые проблемы до приезда гостей", "Redo properly", "Patch quickly", "Переделать нормально", "Быстро подправить", "home renovation", "ремонта дома", "a durable repair", "a presentable home this week", "долговечный ремонт", "приличный вид дома на этой неделе"),
    ]
  ),
  block(
    "personal_gain_vs_collective_impact",
    "Personal gain vs collective impact",
    "Личная выгода vs коллективные последствия",
    "Each case asks whether to choose the personally convenient or profitable option when it creates broader social or environmental costs.",
    "Каждый кейс спрашивает, выбирать ли лично удобный или выгодный вариант, если он создает более широкие социальные или экологические издержки.",
    "The topics intentionally span transport, shopping, housing, education, climate, and public services.",
    "Темы намеренно охватывают транспорт, покупки, жилье, образование, климат и общественные сервисы.",
    "personal benefit, convenience, and direct advantage",
    "my immediate needs are concrete and close",
    "collective impact, sustainability, and civic responsibility",
    "It may add harm that is spread across many people.",
    "It may cost me time, money, or convenience for a diffuse benefit.",
    "личную выгоду, удобство и прямое преимущество",
    "мои ближайшие нужды конкретны и близки",
    "коллективные последствия, устойчивость и гражданскую ответственность",
    "Это может добавить вред, распределенный между многими людьми.",
    "Это может стоить мне времени, денег или удобства ради размытой пользы.",
    [
      item("car-commute", "drive alone to work every day", "use slower public transport", "ездить на работу одному на машине", "пользоваться более медленным общественным транспортом", "Drive alone", "Use public transport", "Ездить на машине", "Ездить на транспорте", "commuting", "поездок на работу", "faster and easier mornings", "city congestion and emissions", "более быстрые и легкие утра", "городские пробки и выбросы"),
      item("fast-fashion", "buy cheap clothes for the season", "pay more for durable ethical clothing", "купить дешевую одежду на сезон", "заплатить больше за долговечную этичную одежду", "Buy cheap clothes", "Buy durable clothing", "Купить дешевую одежду", "Купить долговечную одежду", "clothing purchase", "покупки одежды", "lower immediate spending", "labor and waste impacts", "меньшие расходы сейчас", "условия труда и отходы"),
      item("last-appointment", "take the last convenient appointment", "leave it for someone with a greater need", "забрать последнее удобное время записи", "оставить его тому, кому нужнее", "Take the appointment", "Leave it for others", "Взять запись", "Оставить другим", "appointment access", "доступа к записи", "a schedule that works for me", "access for someone under more pressure", "удобный для меня график", "доступ для человека в более трудной ситуации"),
      item("water-use", "keep watering my lawn during restrictions", "let it dry to save water", "продолжать поливать газон при ограничениях", "дать ему высохнуть ради экономии воды", "Water the lawn", "Save water", "Поливать газон", "Экономить воду", "water use", "использования воды", "a pleasant-looking yard", "shared water reserves", "приятный вид двора", "общие запасы воды"),
      item("polluting-job", "take a high-paying job in a polluting industry", "choose lower-paid work with cleaner impact", "взять высокооплачиваемую работу в загрязняющей отрасли", "выбрать менее оплачиваемую работу с более чистым эффектом", "Take the high-paying job", "Choose cleaner work", "Взять высокооплачиваемую работу", "Выбрать чистую работу", "career ethics", "этики карьеры", "financial acceleration", "environmental consequences", "финансовое ускорение", "экологические последствия"),
      item("short-rental", "turn my flat into a short-term rental", "rent it long-term to a local resident", "сдать квартиру посуточно", "сдать ее надолго местному жителю", "Use short-term rental", "Rent long-term locally", "Сдавать посуточно", "Сдать надолго", "housing market", "рынка жилья", "higher income from the flat", "local housing availability", "более высокий доход от квартиры", "доступность жилья для местных"),
      item("private-tutor", "use all my free teaching time for paid tutoring", "volunteer some hours for students who cannot pay", "использовать все свободное время на платное репетиторство", "часть часов волонтерить для учеников без денег", "Do paid tutoring only", "Volunteer some hours", "Только платное репетиторство", "Часть часов волонтерить", "education access", "доступа к образованию", "more predictable income", "access for students without money", "более предсказуемый доход", "доступ для учеников без денег"),
      item("spare-room", "keep my spare room empty for comfort", "host a displaced acquaintance", "держать свободную комнату пустой для комфорта", "приютить знакомого, потерявшего жилье", "Keep the room empty", "Host the acquaintance", "Оставить комнату пустой", "Приютить знакомого", "housing help", "помощи с жильем", "privacy and convenience at home", "a person's urgent shelter need", "домашнюю приватность и удобство", "срочную потребность человека в жилье"),
      item("tax-cut", "vote for a tax cut that helps me", "support funding for public services", "голосовать за снижение налогов, выгодное мне", "поддержать финансирование общественных сервисов", "Vote for the tax cut", "Fund public services", "Голосовать за снижение налогов", "Финансировать сервисы", "public finance", "общественных финансов", "more money in my household", "schools, clinics, and transport", "больше денег в моем бюджете", "школы, поликлиники и транспорт"),
      item("conference-flight", "fly to a conference for networking", "attend remotely to reduce emissions", "лететь на конференцию ради нетворкинга", "участвовать удаленно ради снижения выбросов", "Fly to the conference", "Attend remotely", "Лететь на конференцию", "Участвовать удаленно", "professional travel", "рабочих поездок", "better networking in person", "the climate cost of travel", "лучший личный нетворкинг", "климатическую цену перелета"),
    ]
  ),
];

function item(
  id,
  enLeft,
  enRight,
  ruLeft,
  ruRight,
  enLeftTitle,
  enRightTitle,
  ruLeftTitle,
  ruRightTitle,
  enTopic,
  ruTopic,
  enLeftOutcome,
  enRightStake,
  ruLeftOutcome,
  ruRightStake
) {
  return {
    id,
    enTopic,
    ruTopic,
    enLeft,
    enRight,
    ruLeft,
    ruRight,
    enLeftTitle,
    enRightTitle,
    ruLeftTitle,
    ruRightTitle,
    enLeftOutcome,
    enRightStake,
    ruLeftOutcome,
    ruRightStake,
  };
}

function block(
  id,
  enTitle,
  ruTitle,
  enComment,
  ruComment,
  enIntent,
  ruIntent,
  enLeftValue,
  enLeftSignal,
  enRightValue,
  enLeftCost3,
  enRightCost3,
  ruLeftValue,
  ruLeftSignal,
  ruRightValue,
  ruLeftCost3,
  ruRightCost3,
  items
) {
  return {
    id,
    enTitle,
    ruTitle,
    enComment,
    ruComment,
    enIntent,
    ruIntent,
    en: {
      leftValue: enLeftValue,
      leftSignal: enLeftSignal,
      rightValue: enRightValue,
      leftCost3: enLeftCost3,
      rightCost3: enRightCost3,
    },
    ru: {
      leftValue: ruLeftValue,
      leftSignal: ruLeftSignal,
      rightValue: ruRightValue,
      leftCost3: ruLeftCost3,
      rightCost3: ruRightCost3,
    },
    items,
  };
}

function draft(block, item, language) {
  if (language === "en") {
    return {
      schemaVersion: 1,
      id: `${block.id}-${item.id}`,
      conflictCluster: block.id,
      rawText: `Should I ${item.enLeft} or ${item.enRight}?`,
      options: [
        {
          title: item.enLeftTitle,
          benefits: [
            `It supports ${block.en.leftValue} in a concrete ${item.enTopic} decision.`,
            `It can create ${item.enLeftOutcome}.`,
            `It gives the choice a stronger sense that ${block.en.leftSignal}.`,
          ],
          costs: [
            `It weakens ${block.en.rightValue} that also matters here.`,
            `It may put pressure on ${item.enRightStake}.`,
            block.en.leftCost3,
          ],
        },
        {
          title: item.enRightTitle,
          benefits: [
            `It protects ${block.en.rightValue} in this ${item.enTopic} situation.`,
            `It keeps ${item.enRightStake} safer and more predictable.`,
            `It avoids paying too much for ${block.en.leftValue}.`,
          ],
          costs: [
            `It may sacrifice ${block.en.leftValue}.`,
            `It can leave ${item.enLeftOutcome} out of reach.`,
            block.en.rightCost3,
          ],
        },
      ],
    };
  }

  return {
    schemaVersion: 1,
    id: `${block.id}-${item.id}`,
    conflictCluster: block.id,
    rawText: `Стоит ли ${item.ruLeft} или ${item.ruRight}?`,
    options: [
      {
        title: item.ruLeftTitle,
        benefits: [
          `Этот вариант поддерживает ${block.ru.leftValue} в теме ${item.ruTopic}.`,
          `Он может принести такой результат: ${item.ruLeftOutcome}.`,
          `Он усиливает ощущение, что ${block.ru.leftSignal}.`,
        ],
        costs: [
          `Он ослабляет ${block.ru.rightValue}, которые здесь тоже важны.`,
          `Он может поставить под давление: ${item.ruRightStake}.`,
          block.ru.leftCost3,
        ],
      },
      {
        title: item.ruRightTitle,
        benefits: [
          `Этот вариант защищает ${block.ru.rightValue} в теме ${item.ruTopic}.`,
          `Он помогает удержать под контролем: ${item.ruRightStake}.`,
          `Он помогает не платить слишком высокую цену за ${block.ru.leftValue}.`,
        ],
        costs: [
          `Он может пожертвовать ${block.ru.leftValue}.`,
          `Он может оставить без результата: ${item.ruLeftOutcome}.`,
          block.ru.rightCost3,
        ],
      },
    ],
  };
}

function dataset(language) {
  return blocks.map((sourceBlock) => ({
    schemaVersion: 1,
    id: sourceBlock.id,
    title: language === "en" ? sourceBlock.enTitle : sourceBlock.ruTitle,
    comment: language === "en" ? sourceBlock.enComment : sourceBlock.ruComment,
    intent: language === "en" ? sourceBlock.enIntent : sourceBlock.ruIntent,
    dilemmas: sourceBlock.items.map((sourceItem) => draft(sourceBlock, sourceItem, language)),
  }));
}

function writeDataset(fileName, language) {
  const filePath = path.join(outputDir, fileName);
  fs.writeFileSync(filePath, `${JSON.stringify(dataset(language), null, 2)}\n`);
}

function formatTextDataset(language) {
  const blocks = dataset(language);
  const labels = language === "en"
    ? {
        heading: "Dilemma Import Dataset",
        summary: "Human-readable version of the block JSON import dataset.",
        block: "BLOCK",
        id: "ID",
        comment: "Comment",
        intent: "Intent",
        dilemma: "Dilemma",
        rawText: "Raw text",
        option: "Option",
        benefits: "Benefits",
        costs: "Costs",
      }
    : {
        heading: "Набор Дилемм Для Импорта",
        summary: "Человекочитаемая версия block JSON dataset.",
        block: "БЛОК",
        id: "ID",
        comment: "Комментарий",
        intent: "Замысел",
        dilemma: "Дилемма",
        rawText: "Raw text",
        option: "Опция",
        benefits: "Плюсы",
        costs: "Минусы",
      };

  const totalDilemmas = blocks.reduce((sum, block) => sum + block.dilemmas.length, 0);
  const lines = [
    labels.heading,
    "=".repeat(labels.heading.length),
    "",
    labels.summary,
    `${blocks.length} blocks, ${totalDilemmas} dilemmas.`,
    "",
  ];

  blocks.forEach((block, blockIndex) => {
    lines.push(
      `${labels.block} ${blockIndex + 1}: ${block.title}`,
      "-".repeat(`${labels.block} ${blockIndex + 1}: ${block.title}`.length),
      `${labels.id}: ${block.id}`,
      `${labels.comment}: ${block.comment}`,
      `${labels.intent}: ${block.intent}`,
      ""
    );

    block.dilemmas.forEach((dilemma, dilemmaIndex) => {
      lines.push(
        `${dilemmaIndex + 1}. ${labels.dilemma}: ${dilemma.id}`,
        `${labels.rawText}: ${dilemma.rawText}`
      );

      dilemma.options.forEach((option, optionIndex) => {
        lines.push(
          `${labels.option} ${optionIndex + 1}: ${option.title}`,
          `${labels.benefits}:`
        );
        option.benefits.forEach((benefit) => lines.push(`  + ${benefit}`));
        lines.push(`${labels.costs}:`);
        option.costs.forEach((cost) => lines.push(`  - ${cost}`));
      });

      lines.push("");
    });

    lines.push("");
  });

  return lines.join("\n").replace(/\n{3,}/g, "\n\n");
}

function writeTextDataset(fileName, language) {
  const filePath = path.join(outputDir, fileName);
  fs.writeFileSync(filePath, `${formatTextDataset(language)}\n`);
}

writeDataset("dilemmas_en_blocks.json", "en");
writeDataset("dilemmas_ru_blocks.json", "ru");
writeTextDataset("dilemmas_en_blocks.txt", "en");
writeTextDataset("dilemmas_ru_blocks.txt", "ru");

const enCount = dataset("en").reduce((total, block) => total + block.dilemmas.length, 0);
const ruCount = dataset("ru").reduce((total, block) => total + block.dilemmas.length, 0);
console.log(`Generated ${enCount} English dilemmas and ${ruCount} Russian dilemmas as JSON and TXT.`);
