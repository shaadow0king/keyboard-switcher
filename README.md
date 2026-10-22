# Mistype

Бесплатная программа для Mac, которая исправляет текст, набранный не в той раскладке: `ghbdtn` → `привет`,
`руддщ` → `hello`. Без подписки.

[**Скачать последнюю версию**](https://github.com/shaadow0king/keyboard-switcher/releases/latest/download/Mistype.dmg) ·
нужна macOS 15 или новее, подходит любой Mac (Apple Silicon и Intel).

## Что умеет

- Исправляет слово в неправильной раскладке, как только вы нажимаете пробел. Короткие слова исправляются вместе
  со следующим: `z ljvf` → `я дома`.
- Клавиша <kbd>⌥</kbd> (или любая своя) переводит последнее слово или выделенный текст в другую раскладку, а повторное
  нажатие возвращает как было.
- Приложения, где Mistype молчит: Терминал, редакторы кода, игры.
- Слова, которые никогда не нужно трогать.
- Поля паролей пропускаются.
- Показывает текущую раскладку (RU / EN) в строке меню. Интерфейс на русском и английском.

## Установка

1. Скачайте `Mistype.dmg` и откройте его. В окне перетащите **Mistype** в папку «Программы».
2. Откройте Mistype из «Программ» (не из окна образа). Программа подписана и проверена Apple, поэтому macOS откроет
   её без предупреждений. Окна у неё нет: она появится в строке меню как RU / EN.
3. Mistype попросит доступ «Универсальный доступ»: без него macOS не даёт исправлять текст в других окнах. Окно
   подскажет, где его включить, и закроется само.

Чтобы выключить разрешение позже, сначала закройте Mistype (меню → «Завершить Mistype»).

## Приватность

То, что вы печатаете, не сохраняется и не покидает ваш Mac. Единственный сетевой запрос — раз в день Mistype
спрашивает у GitHub, вышла ли новая версия (выключается во вкладке «О программе»). Ни аналитики, ни отчётов о сбоях.

## Обновления

Mistype сам проверяет новые версии и покажет в меню «Доступно обновление». Скачайте новую версию и замените ею старую
в «Программах».

## Отзывы и предложения

Настройки → «О программе» → «Отзывы и предложения», или [issue на GitHub](https://github.com/shaadow0king/keyboard-switcher/issues).

## Сборка из исходников

```bash
swift test          # тесты
./build.sh          # собирает и подписывает build/Mistype.app
./release.sh 0.2    # выпуск на GitHub (спросит перед публикацией)
```

---

**English.** Mistype is a free Mac app that fixes text typed in the wrong keyboard layout (Russian ⇄ English) as you
type, with one key to convert or undo, a list of apps where it stays off, and password fields skipped. What you type
never leaves your Mac; it only checks GitHub for new versions. Requires macOS 15 or later, on Apple Silicon or Intel.
Open Mistype.dmg, drag Mistype to Applications and open it from there; it's signed and notarized by Apple and asks
for Accessibility on first open.
