export const materialTypes = {
  cotton: "Хлопок",
  denim: "Деним",
  linen: "Лён",
  wool: "Шерсть",
  synthetic: "Синтетика",
  mixed: "Смесовая ткань",
};

export const conditions = {
  unused: "Новые остатки производства",
  good: "В хорошем состоянии",
  worn: "С признаками износа",
  damaged: "Есть повреждения",
};

export const initialMaterials = [
  {
    id: "demo-cotton",
    name: "Хлопок натуральных оттенков",
    material_type: "cotton",
    composition: "Хлопок, по данным продавца",
    total_kg: "100.000",
    price_per_kg: "80.00",
    city: "Бишкек",
    scrap_size: "От 20 × 30 см",
    condition: "unused",
    organization_name: "Цех «Текстиль»",
    image: "/images/cotton-offcuts.webp",
    description:
      "Светлые хлопковые остатки после раскроя. Подойдут для небольших изделий, подкладок и творческих проектов.",
    created_at: "2026-11-07T08:00:00Z",
  },
  {
    id: "demo-denim",
    name: "Деним для новых историй",
    material_type: "denim",
    composition: "Состав не подтверждён",
    total_kg: "65.000",
    price_per_kg: "120.00",
    city: "Бишкек",
    scrap_size: "От 15 × 20 см",
    condition: "unused",
    organization_name: "Цех «Индиго»",
    image: "/images/denim-offcuts.webp",
    description:
      "Обрезки денима разных оттенков. Плотная фактура для аксессуаров, лоскутных изделий и декоративных деталей.",
    created_at: "2026-11-07T07:00:00Z",
  },
  {
    id: "demo-linen",
    name: "Лён и фактурные остатки",
    material_type: "linen",
    composition: "Лён, по данным продавца",
    total_kg: "40.000",
    price_per_kg: "95.00",
    city: "Ош",
    scrap_size: "От 30 × 40 см",
    condition: "unused",
    organization_name: "Мастерская «Лён»",
    image: "/images/textile-hero.webp",
    description:
      "Крупные остатки спокойных природных оттенков. Материал для интерьерного текстиля и многоразовой упаковки.",
    created_at: "2026-11-06T12:00:00Z",
  },
  {
    id: "demo-mixed",
    name: "Цветной микс для мастерских",
    material_type: "mixed",
    composition: "Смешанный, требует проверки",
    total_kg: "85.500",
    price_per_kg: "45.00",
    city: "Бишкек",
    scrap_size: "Разные размеры",
    condition: "good",
    organization_name: "Цех «Новый крой»",
    image: "/images/textile-hero.webp",
    description:
      "Разноцветные остатки тканей. Потребуется сортировка по составу и размеру перед использованием.",
    created_at: "2026-11-06T10:00:00Z",
  },
  {
    id: "demo-cotton-small",
    name: "Мелкий хлопковый лоскут",
    material_type: "cotton",
    composition: "Хлопок, по данным продавца",
    total_kg: "32.000",
    price_per_kg: "35.00",
    city: "Кара-Балта",
    scrap_size: "От 5 × 10 см",
    condition: "good",
    organization_name: "Цех «Узор»",
    image: "/images/cotton-offcuts.webp",
    description:
      "Небольшие хлопковые лоскуты. Возможность использования зависит от требований конкретного производства.",
    created_at: "2026-11-05T09:00:00Z",
  },
  {
    id: "demo-denim-large",
    name: "Крупный лоскут денима",
    material_type: "denim",
    composition: "Состав не подтверждён",
    total_kg: "25.000",
    price_per_kg: "140.00",
    city: "Токмок",
    scrap_size: "От 40 × 50 см",
    condition: "unused",
    organization_name: "Мастерская «Крой»",
    image: "/images/denim-offcuts.webp",
    description:
      "Крупные отрезы после производства одежды. Можно рассмотреть для пошива сумок и чехлов.",
    created_at: "2026-11-05T08:00:00Z",
  },
];

export const reuseIdeas = {
  cotton: [
    {
      title: "Шоперы и упаковка",
      buyer: "Мастерские аксессуаров",
      reason:
        "Крупные чистые отрезы можно использовать для небольших сумок и мешочков.",
    },
    {
      title: "Интерьерный текстиль",
      buyer: "Студии текстиля",
      reason:
        "После проверки плотности и размеров можно подобрать лоскуты для декора и подкладок.",
    },
    {
      title: "Техническая ветошь",
      buyer: "Производственные мастерские",
      reason:
        "Мелкие чистые остатки могут подойти для технических задач после проверки состава.",
    },
  ],
  denim: [
    {
      title: "Сумки и чехлы",
      buyer: "Мастерские аксессуаров",
      reason:
        "Плотные отрезы можно соединить в прочное полотно. Швы и прочность нужно проверить.",
    },
    {
      title: "Лоскутные изделия",
      buyer: "Ремесленные студии",
      reason:
        "Разные оттенки денима подходят для декоративных сочетаний и небольших изделий.",
    },
    {
      title: "Восстановленное волокно",
      buyer: "Переработчики текстиля",
      reason:
        "Мелкие остатки можно предложить переработчику после уточнения состава и требований.",
    },
  ],
  default: [
    {
      title: "Небольшие изделия",
      buyer: "Ремесленные мастерские",
      reason:
        "Размеры, состав и состояние нужно сопоставить с требованиями будущего изделия.",
    },
    {
      title: "Декор и упаковка",
      buyer: "Студии текстиля",
      reason:
        "Крупные чистые отрезы могут подойти для декоративных деталей и многоразовой упаковки.",
    },
    {
      title: "Переработка",
      buyer: "Переработчики текстиля",
      reason:
        "Для выбора технологии необходимо подтвердить состав и отсутствие загрязнений.",
    },
  ],
};
