# Соль и Железо

3D-хоррор о сверхъестественном на Godot 4.3 (Mobile renderer). Дом Холлисов,
призрак Эдит Холлис, игрок Нейт Колдер. Соль и железо — единственная защита.

## Как играть

1. Найдите три реликвии: медальон, фотографию и музыкальную шкатулку.
   Каждая делает Эдит злее.
2. Когда реликвии собраны, подвал откроется. Спуститесь вниз и сожгите
   останки Эдит (подойдите и удерживайте ДЕЙСТВИЕ).
3. Защищайтесь: кочерга (КОЧЕРГА) оглушает вплотную, соль (СОЛЬ) — на дистанции.
   Следите за EMF-метром и здоровьем.

Управление на телефоне: левый джойстик — движение, свайп справа — обзор,
кнопки справа внизу — ДЕЙСТВИЕ / КОЧЕРГА / СОЛЬ / ФОНАРЬ.
На ПК: WASD + мышь, E — действие, F — фонарь, Q — кочерга, R — соль.

## Android APK

Готовый APK лежит в репозитории: **`build/salt-and-iron.apk`**
(пакет `com.cotyk207.saltandiron`, версия 1.0.0, Android 7.0+ / API 24+,
arm64-v8a + armeabi-v7a, landscape).

Установка на телефон:

1. Скачайте `build/salt-and-iron.apk` из репозитория.
2. Разрешите установку из неизвестных источников для браузера/файлового менеджера.
3. Установите APK и запустите «Соль и Железо».

APK подписан отладочным ключом (для sideload). Для публикации в Google Play
нужен релизный ключ — см. `export_presets.cfg` (секция `keystore/release`).

## Сборка

Проект: Godot 4.3, главная сцена `main.tscn`, скрипты в `scripts/`
(`main.gd` — контроллер, `house.gd`, `ghost.gd`, `player.gd`, `hud.gd`, `mats.gd`).

Локально (нужны Godot 4.3 + export templates + JDK 17 + Android SDK):

```bash
godot --headless --import
godot --headless --export-release "Android" build/salt-and-iron.apk
```

В CI: workflow **Build Android APK** (`.github/workflows/build-apk.yml`)
собирает APK на `ubuntu-latest` и загружает его как artifact
` salt-and-iron-apk`. Запуск: `gh workflow run "Build Android APK" --ref <branch>`,
скачать: `gh run download <run-id> -n salt-and-iron-apk -D build/`.
