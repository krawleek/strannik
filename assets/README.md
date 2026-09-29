# Локальные assets Home

Источник — утверждённый Home `453:12057` файла Figma
`https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App?node-id=453-12057`.
Ссылки MCP не используются в коде и не сохранены в каталоге.

| Asset | Узел / происхождение |
| --- | --- |
| `backgrounds/background.png` | `453:12058`, только иллюстрация комнаты |
| `illustrations/pet.png` | `453:12074`, кот с исходным прозрачным отступом |
| `icons/pet_avatar.png` | `453:16878` |
| `icons/child_avatar.png` | `453:16879` |
| `icons/nav_home.png` | `333:2596` |
| `icons/nav_store.png` | `333:2602` |
| `icons/nav_bank.png` | `333:2616` |
| `icons/nav_learning.png` | `333:2624` |
| `icons/stage_star.png` | звезда из индикатора Home, без числовой надписи |
| `illustrations/bubble_fill.png` | `414:11716`, только контур заливки |
| `illustrations/bubble_outline.png` | `414:11715`, только обводка |

`illustrations/bubble.png` объединяет исходную заливку и обводку в один
прозрачный asset для nine-slice; надписи и кнопки в него не входят.

`source/` хранит оригинальные экспортированные SVG без перерисовки. Для Flutter
они растеризованы в PNG 1x и 3x; дополнительных runtime SVG-пакетов нет.
Фон — исходный PNG-экспорт 360×800; на устройствах с высокой плотностью он может
быть мягче векторных иллюстраций. Экспорт также содержит скругление внешних углов.
Текст, числовые значения, кнопки, hit targets и navigation — Flutter widgets;
изображения целого Home в приложении нет.

`fonts/` содержит предоставленные пользователем официальные статические Manrope:
SemiBold 600, Bold 700, ExtraBold 800 и исходную SIL Open Font License
`Manrope-OFL.txt`. Шрифты загружаются из приложения, без Google Fonts/network.

Разрешение domain ID → asset находится только в
`lib/presentation/assets/presentation_assets.dart`. Неизвестные skin/avatar ID
используют рыжего кота/девочку. Для неподготовленного accessory применяется
иконка сумки в пояснении overlay; она не изображает надетый аксессуар на коте.
Ни один fallback не переписывает domain ID.
