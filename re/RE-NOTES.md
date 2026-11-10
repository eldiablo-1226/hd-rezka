# HDRezka.ipa — карта реверса

Статический анализ, приложение не запускалось. Всё, что ниже, взято из самого бинаря и ресурсов; где это вывод, а не факт, так и помечено.

## Что это за IPA
- `me.keet.HDRezka`, версия 1.6.0 (570), iOS 16.0+, iPhone и iPad. Собрано в Xcode 26.4 (SDK iOS 26.4).
- Подписи нет, `cryptid 0` (не зашифровано). Распространяется для сайдлоада через TrollStore или AltStore.
- Один исполняемый файл `HDrezka` (arm64, 15.6 MB). SwiftUI, Swift-модуль `HDrezka`, 143 собственных типа. Символы не вырезаны.
- SPM-зависимости вшиты статически: Alamofire, SwiftSoup (парсинг HTML), Nuke и NukeUI (картинки), YouTubePlayerKit (трейлеры), AlertKit (тосты), Flow (раскладка), Firebase 11.x (Crashlytics, Analytics, Sessions).
- `GoogleService-Info.plist` принадлежит Firebase-проекту разработчика (`hdrezka-ios`).
- Схема URL `hdr://`, фоновый режим `audio`, общий доступ к файлам (загрузки видны в «Файлах»), `NSAllowsArbitraryLoads`.

## Архитектура (по метаданным типов; полный дамп в `swift-interface.txt`)
- **Точка входа:** `HDRezkaApp` (App) с `AppDelegate` (обработчик завершения фоновой сессии), `DownloadManager` как StateObject и `Network`.
- **Сеть и парсинг.** Классы `Network`, `AccountNetwork`, `CollectionsNetwork`, `PeopleNetwork`, `MovieDetailsService` работают поверх Alamofire. HTML разбирают `MovieDetailsParser`, `AccountParser`, `CollectionsParser`, `PeopleParser` через SwiftSoup, то есть приложение скрейпит сайт.
- **Зеркало.** `@AppStorage settingStore` хранит домен (меняется в DebugSettingsView). Есть ещё `remoteVersion`. `https://api.hdrezka.tech/get.hdrezka_android_app_updates` — это эндпоинт обновлений официального Android-приложения. Вероятно, приложение берёт из него актуальное зеркало; это вывод, по коду не подтверждено.
- **Заголовки запросов:** `X-Hdrezka-Ios-App`, `X-Hdrezka-Ios-App-Version`.
- **Плеер.** `PlayerViewComponent` (AVPlayerViewController) с координатором: прогресс, PiP, Now Playing, автопереход к следующей серии. `CustomAVPlayer` и `CustomAVAssetResourceLoaderDelegate` на лету собирают m3u8-плейлист со схемами `fragmentsm3u8://` и `subtitlesm3u8://`, чтобы встроить внешние субтитры. Поддерживается внешний плеер Infuse (`infuse://x-callback-url/play`).
- **Загрузки.** `DownloadManager`: обычная и фоновая `URLSession`, назначение «приложение / галерея / Файлы», состояние хранится в `me.keet.HDRezka.downloads.storage` (Codable `Download`).
- **Прогресс просмотра.** `PlaybackProgressStore` хранит его в CoreData (`PlaybackProgress.sqlite`, сущность `PlaybackProgress`). Файла `.momd` в бандле нет, значит модель задаётся в коде.
- **Аккаунт:** вход и регистрация, закладки и их категории, «Досмотреть», обновления сериалов, статус Premium (`.b-tophead-premuser`).

## Эндпоинты сайта (из строк бинаря)
| Назначение | Путь |
|---|---|
| Видео/серии (POST) | `/ajax/get_cdn_series/?t=` |
| Сохранить прогресс | `/ajax/send_save/?t=` |
| Закладки | `/ajax/favorites/` |
| Удалить из «Досмотреть» | `/engine/ajax/cdn_saves_remove.php` |
| Вход / регистрация | `/engine/ajax/quick_register.php` (вход), `/engine/ajax/registration.php` (проверка ника/почты) |
| Трейлер | `/engine/ajax/gettrailervideo.php` |
| Поиск | `/engine/ajax/search.php/` (быстрый), `/search/?do=search&subaction=search` |
| Подборки | `/collections/page/` |

## Селекторы SwiftSoup (самое хрупкое место)
`div.b-content__inline_item(-cover|-link)`, `div.b-post__title`, `b-post__origtitle`, `table.b-post__info`, `b-post__info_rates kp|imdb`, `ul#translators-list` / `b-translator__item` / `data-translator_id` / `b-prem_translator`, `ul#simple-seasons-tabs`, `ul#simple-episodes-list-*`, `initCDNMoviesEvents` / `initCDNSeriesEvents` (параметры плеера из inline-JS), `div.b-post__schedule_block*`, `div.b-post__partcontent_item` (франшиза), `div.b-player__restricted` (регион), `div.b-seriesupdate__block*`, `div.b-videosaves__list_item`, `div.b-favorites_content__cats_list_item`, `div.b-content__collections_item`, `div.b-person__career`, `div.b-post__infotable_*`.

## Настройки (@AppStorage)
В `__cstring` нашлись длинные ключи: `shareMenuVariation`, `startupPageVariation`, `downloadDestination`, `preferOriginalTitle`, `background_url_session`, `autoplayNextEpisode`, `preferredQuality`. Короткие ключи (до 15 байт) Swift хранит прямо в инструкциях, поэтому их нужно достать из дизассемблера: `settingStore`, `remoteVersion`, `isLoggedIn`, `hasPremium`, `isHidingNotch`, `useInfuse`, `showVotesCount`, `allowDebug`, `saveHistory`. Имена переменных этих ключей известны, а сами строки ещё нет.

## Настройки: ключи и умолчания (подтверждено по дизассемблеру)
Файл `appstorage-keys.tsv` перечисляет все 139 мест создания `@AppStorage`. Ключи: `mirror` (переменная `settingStore`, по умолчанию `ijobs.app`), `remoteVersion` (`""`, в части мест `"0.0.0"`), `isLoggedIn`, `hasPremium` (`""`), `hideNotch` (переменная `isHidingNotch`), `useInfuse`, `showVotesCount`, `background_url_session` (в `ProfileView` по умолчанию `false`, в `DownloadManager` `true`), `allowDebug`, `autoplayNextEpisode` (в `ProfileView` `true`, в `QualitySelectionSheet` `false`), `saveHistory` (`true`), `preferOriginalTitle`, `shareMenuVariation` (`.url`), `startupPageVariation` (`.watching`), `preferredQuality` (`.ask`), `downloadDestination` (`.app`).
Raw-значения enum'ов взяты из таблиц `_findStringSwitchCase`:
- `StartupPageVariation`: `Now watching`, `key_last_releases`, `key_popular`, `key_comingsoon`.
- `PlayerQualityPreference`: `ask`, `360p`, `480p`, `720p`, `1080p`, `1080p Ultra`, `2K`, `4K`.
- `DownloadState`: `downloading`, `paused`, `completed`, `failed`.
- `ShareMenuVariation`: `selectOption`, `url`, `universalLink`.
- `DownloadDestination`: `app`, `gallery`, `files`.

## Проверено на живом зеркале (ijobs.app, из Узбекистана, 2026-11-10)
- Зеркало требует заголовок `X-Hdrezka-Ios-App`: без него ответ 403 даже с UA приложения. UA `curl/…` блокируется. Любой другой UA с этим заголовком проходит, в том числе `MyApp/2.0 …` и `Alamofire/x`, и листинги (`/`, `/page/2/`, `/films/`) отдаются с кодом 200. Стандартный UA Alamofire в пересобранном приложении проходит.
- Страницы фильмов отдают 403 при любых комбинациях заголовков, cookie, версий и UA, в том числе браузерного. Оригинал запрашивает страницу GET'ом только с двумя заголовками, `X-Hdrezka-Ios-App` и `-Version` (замыкание `0x10004f004`). Причина подтверждена: из этой сети страницы фильмов и сериалов закрыты для гостей, а после входа в аккаунт тот же запрос получает 200 и страница открывается (проверено в собранном приложении в симуляторе). 403 с пустым телом отдаёт прослойка Express за nginx, и в этом ответе сервер удаляет cookie входа DLE (`dle_user_id`, `dle_password`, `dle_hash`). Гостевые cookie из ответа на запрос списка не помогают; страницы персон гостю отдаются (200). В оригинале остались переменные VPN-попапа (`connectedToVpn`, `vpnPopup`) и строка «Для открытия сайта может потребоваться VPN».
- `POST /ajax/get_cdn_series/` работает и отдаёт ссылки без обфускации.

## Ответы на прежние открытые вопросы
1. **Ссылки на поток не обфусцированы.** Сервер отдаёт `[360p]https://…mp4,[480p]…` открытым текстом. `String.getMovieVideo()` разбирает метки качества через SwiftSoup (метки бывают HTML) и сохраняет ссылки как есть; у гостя ссылка 1080p приходит строкой `null`. Подробности в `reports/a1b.md`.
2. **Эндпоинт обновлений** `api.hdrezka.tech/get.hdrezka_android_app_updates` возвращает JSON `{"version":"2.2.5",…}`. `HeaderUpdater.updateHeader()` берёт из него `version` и кладёт в `remoteVersion`, а это значение уходит в заголовок `X-Hdrezka-Ios-App-Version`. Зеркало из этого эндпоинта не выбирается: оно задано жёстко (`DefaultSettings.mirror = "ijobs.app"`) и меняется в отладочных настройках.
3. **Модель CoreData** `PlaybackProgress`: атрибуты `key` (String), `time` (Double, по умолчанию 0) и `updatedAt` (Date). Хранилище `Application Support/PlaybackProgress.sqlite`, лёгкая миграция. Подробности в `reports/b.md`.
4. **Ключи и умолчания AppStorage** описаны выше в разделе «Настройки». Все места их создания перечислены в `appstorage-keys.tsv`.

## Версии зависимостей (подтверждено по бинарю)
| Пакет | Версия | Почему именно она |
|---|---|---|
| Alamofire | 5.8.0 | User-Agent заканчивается на `Alamofire/5.8.0` |
| SwiftSoup | 2.6.1 | `hasClass` работает на `String` и сравнивает атрибут класса целиком; void-теги выводятся как `<br>` |
| Nuke | 12.8.0 | В бинаре нет проверок изоляции Swift 6. Версия 12.9 собирается в режиме Swift 6, и её `LazyImage` роняет приложение, когда список обновляется не на главном потоке |
| YouTubePlayerKit 1.9.0, AlertKit 5.1.10, SwiftUI-Flow 1.7.0 | — | Совпадают по API, отдельной сверки не было |

## Инструменты
- `tools/swiftmeta.py` — парсер `__swift5_types`, `__swift5_fieldmd` и `__swift5_proto` (типы, поля, конформансы). Запуск: `python3 -I re/tools/swiftmeta.py <macho> <dyld_info -fixups> HDrezka`.
- Hopper доступен через REA. Открывать нужно сам Mach-O, а не `.ipa`.
