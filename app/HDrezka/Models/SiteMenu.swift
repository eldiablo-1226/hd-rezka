import Foundation

/// A link of the site's header menu. `path` is relative to the mirror and ends in a slash ("films/drama/").
struct SiteLink: Hashable {
    let name: String
    let path: String
    /// A studio's collection under its own name ("Фильмы Netflix"); the menu shows the studio alone.
    var title: String? = nil
}

/// A dropdown of the site's header (Фильмы, Сериалы, Мультфильмы, Аниме): its genres, its studios, its «Лучшие».
struct SiteSection: Identifiable {
    /// The site's path component ("films"); it also names the section's strings ("key_section_films").
    let id: String
    let symbol: String
    let genres: [SiteLink]
    let studios: [SiteLink]

    var path: String { "\(id)/" }
    var titleKey: String { "key_section_\(id)" }
    var allKey: String { "key_section_all_\(id)" }
    var bestKey: String { "key_section_best_\(id)" }
    var findBestKey: String { "key_section_find_best_\(id)" }

    /// The site's «Найти лучшие» link: "films/best/", then the genre's slug and the year; year 0 is «за все время».
    func bestPath(genre: SiteLink?, year: Int) -> String {
        var path = "\(id)/best/"
        if let slug = genre?.path.split(separator: "/").last { path += "\(slug)/" }
        if year > 0 { path += "\(year)/" }
        return path
    }
}

/// improvement: the site's header menu for the «Каталог» tab, in the site's order (Подборки is the tab's own grid).
enum SiteMenu {
    static let new = "new/"
    static let announce = "announce/"

    /// «Лучшие новинки»: the best of the current year.
    static func currentYear(now: Date = Date()) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: now)
    }

    /// The site's year picker: next year down to 1896, without the years it has nothing for.
    static func years(now: Date = Date()) -> [Int] {
        (1896...currentYear(now: now) + 1).reversed().filter { !(1897...1901).contains($0) && $0 != 1904 }
    }

    // shortcut: a snapshot of the site's `#topnav-menu` (ijobs.app, saved 2026-11-10; SiteMenuTests holds it to that
    // page). Parse the menu from a loaded page if the site starts changing it.
    static let sections: [SiteSection] = [
        SiteSection(id: "films", symbol: "film", genres: [
            SiteLink(name: "Вестерны", path: "films/western/"),
            SiteLink(name: "Семейные", path: "films/family/"),
            SiteLink(name: "Фэнтези", path: "films/fantasy/"),
            SiteLink(name: "Биографические", path: "films/biographical/"),
            SiteLink(name: "Арт-хаус", path: "films/arthouse/"),
            SiteLink(name: "Боевики", path: "films/action/"),
            SiteLink(name: "Военные", path: "films/military/"),
            SiteLink(name: "Детективы", path: "films/detective/"),
            SiteLink(name: "Криминал", path: "films/crime/"),
            SiteLink(name: "Приключения", path: "films/adventures/"),
            SiteLink(name: "Драмы", path: "films/drama/"),
            SiteLink(name: "Спортивные", path: "films/sport/"),
            SiteLink(name: "Фантастика", path: "films/fiction/"),
            SiteLink(name: "Комедии", path: "films/comedy/"),
            SiteLink(name: "Мелодрамы", path: "films/melodrama/"),
            SiteLink(name: "Триллеры", path: "films/thriller/"),
            SiteLink(name: "Ужасы", path: "films/horror/"),
            SiteLink(name: "Мюзиклы", path: "films/musical/"),
            SiteLink(name: "Музыкальные", path: "films/musical/"),
            SiteLink(name: "Исторические", path: "films/historical/"),
            SiteLink(name: "Документальные", path: "films/documentary/"),
            SiteLink(name: "Эротика", path: "films/erotic/"),
            SiteLink(name: "Детские", path: "films/kids/"),
            SiteLink(name: "Путешествия", path: "films/travel/"),
            SiteLink(name: "Познавательные", path: "films/cognitive/"),
            SiteLink(name: "Театр", path: "films/theatre/"),
            SiteLink(name: "Концерт", path: "films/concert/"),
            SiteLink(name: "Стендап", path: "films/standup/"),
            SiteLink(name: "Короткометражные", path: "films/short/"),
            SiteLink(name: "Русские", path: "films/russian/"),
            SiteLink(name: "Украинские", path: "films/ukrainian/"),
            SiteLink(name: "Зарубежные", path: "films/foreign/"),
        ], studios: [
            SiteLink(name: "Netflix", path: "collections/834-filmy-netflix/", title: "Фильмы Netflix"),
            SiteLink(name: "HBO и HBO Max", path: "collections/1419-filmy-hbo/", title: "Фильмы HBO и HBO Max"),
            SiteLink(name: "Amazon", path: "collections/1417-filmy-amazon/", title: "Фильмы Amazon"),
            SiteLink(name: "Disney", path: "collections/1075-filmy-disney/", title: "Фильмы Disney"),
            SiteLink(name: "Apple TV+", path: "collections/1416-filmy-apple-tv/", title: "Фильмы Apple TV+"),
        ]),
        SiteSection(id: "series", symbol: "tv", genres: [
            SiteLink(name: "Военные", path: "series/military/"),
            SiteLink(name: "Боевики", path: "series/action/"),
            SiteLink(name: "Арт-хаус", path: "series/arthouse/"),
            SiteLink(name: "Триллеры", path: "series/thriller/"),
            SiteLink(name: "Ужасы", path: "series/horror/"),
            SiteLink(name: "Приключения", path: "series/adventures/"),
            SiteLink(name: "Семейные", path: "series/family/"),
            SiteLink(name: "Фантастика", path: "series/fiction/"),
            SiteLink(name: "Фэнтези", path: "series/fantasy/"),
            SiteLink(name: "Драмы", path: "series/drama/"),
            SiteLink(name: "Мелодрамы", path: "series/melodrama/"),
            SiteLink(name: "Спортивные", path: "series/sport/"),
            SiteLink(name: "Комедии", path: "series/comedy/"),
            SiteLink(name: "Детективы", path: "series/detective/"),
            SiteLink(name: "Криминал", path: "series/crime/"),
            SiteLink(name: "Исторические", path: "series/historical/"),
            SiteLink(name: "Биографические", path: "series/biographical/"),
            SiteLink(name: "Вестерны", path: "series/western/"),
            SiteLink(name: "Документальные", path: "series/documentary/"),
            SiteLink(name: "Музыкальные", path: "series/musical/"),
            SiteLink(name: "Реальное ТВ", path: "series/realtv/"),
            SiteLink(name: "Телепередачи", path: "series/telecasts/"),
            SiteLink(name: "Стендап", path: "series/standup/"),
            SiteLink(name: "Эротика", path: "series/erotic/"),
            SiteLink(name: "Русские", path: "series/russian/"),
            SiteLink(name: "Украинские", path: "series/ukrainian/"),
            SiteLink(name: "Зарубежные", path: "series/foreign/"),
        ], studios: [
            SiteLink(name: "Netflix", path: "collections/640-serialy-netflix/", title: "Сериалы Netflix"),
            SiteLink(name: "HBO и HBO Max", path: "collections/639-serialy-hbo/", title: "Сериалы HBO и HBO Max"),
            SiteLink(name: "Amazon Prime", path: "collections/831-serialy-amazon/", title: "Сериалы Amazon Prime"),
            SiteLink(name: "Disney+", path: "collections/1148-serialy-disney/", title: "Сериалы Disney+"),
            SiteLink(name: "Apple TV+", path: "collections/1146-serialy-apple-tv/", title: "Сериалы Apple TV+"),
            SiteLink(name: "Hulu", path: "collections/813-serialy-hulu/", title: "Сериалы Hulu"),
            SiteLink(name: "Epix", path: "collections/1251-serialy-epix/", title: "Сериалы Epix"),
        ]),
        SiteSection(id: "cartoons", symbol: "teddybear", genres: [
            SiteLink(name: "Фантастика", path: "cartoons/fiction/"),
            SiteLink(name: "Фэнтези", path: "cartoons/fantasy/"),
            SiteLink(name: "Боевики", path: "cartoons/action/"),
            SiteLink(name: "Биографические", path: "cartoons/biographical/"),
            SiteLink(name: "Комедии", path: "cartoons/comedy/"),
            SiteLink(name: "Вестерны", path: "cartoons/western/"),
            SiteLink(name: "Военные", path: "cartoons/military/"),
            SiteLink(name: "Драмы", path: "cartoons/drama/"),
            SiteLink(name: "Мелодрамы", path: "cartoons/melodrama/"),
            SiteLink(name: "Арт-хаус", path: "cartoons/arthouse/"),
            SiteLink(name: "Детективы", path: "cartoons/detective/"),
            SiteLink(name: "Криминал", path: "cartoons/crime/"),
            SiteLink(name: "Триллеры", path: "cartoons/thriller/"),
            SiteLink(name: "Исторические", path: "cartoons/historical/"),
            SiteLink(name: "Документальные", path: "cartoons/documentary/"),
            SiteLink(name: "Эротика", path: "cartoons/erotic/"),
            SiteLink(name: "Сказки", path: "cartoons/fairytale/"),
            SiteLink(name: "Семейные", path: "cartoons/family/"),
            SiteLink(name: "Ужасы", path: "cartoons/horror/"),
            SiteLink(name: "Приключения", path: "cartoons/adventures/"),
            SiteLink(name: "Спортивные", path: "cartoons/sport/"),
            SiteLink(name: "Познавательные", path: "cartoons/cognitive/"),
            SiteLink(name: "Мюзиклы", path: "cartoons/musical/"),
            SiteLink(name: "Аниме", path: "cartoons/anime/"),
            SiteLink(name: "Детские", path: "cartoons/kids/"),
            SiteLink(name: "Для взрослых", path: "cartoons/adult/"),
            SiteLink(name: "Мультсериалы", path: "cartoons/multseries/"),
            SiteLink(name: "Короткометражные", path: "cartoons/short/"),
            SiteLink(name: "Полнометражные", path: "cartoons/full-length/"),
            SiteLink(name: "Советские", path: "cartoons/soyzmyltfilm/"),
            SiteLink(name: "Русские", path: "cartoons/russian/"),
            SiteLink(name: "Украинские", path: "cartoons/ukrainian/"),
            SiteLink(name: "Зарубежные", path: "cartoons/foreign/"),
        ], studios: [
            SiteLink(name: "Netflix", path: "collections/1004-animacionnye-serialy-netflix/", title: "Мультфильмы Netflix"),
            SiteLink(name: "Disney", path: "collections/1-multfilmy-disney/", title: "Мультфильмы Disney"),
        ]),
        SiteSection(id: "animation", symbol: "sparkles", genres: [
            SiteLink(name: "Военные", path: "animation/military/"),
            SiteLink(name: "Драмы", path: "animation/drama/"),
            SiteLink(name: "Детективы", path: "animation/detective/"),
            SiteLink(name: "Триллеры", path: "animation/thriller/"),
            SiteLink(name: "Комедии", path: "animation/comedy/"),
            SiteLink(name: "Фантастика", path: "animation/fiction/"),
            SiteLink(name: "Фэнтези", path: "animation/fantasy/"),
            SiteLink(name: "Приключения", path: "animation/adventures/"),
            SiteLink(name: "Романтические", path: "animation/romance/"),
            SiteLink(name: "Исторические", path: "animation/historical/"),
            SiteLink(name: "Ужасы", path: "animation/horror/"),
            SiteLink(name: "Мистические", path: "animation/mystery/"),
            SiteLink(name: "Музыкальные", path: "animation/musical/"),
            SiteLink(name: "Эротика", path: "animation/erotic/"),
            SiteLink(name: "Боевики", path: "animation/action/"),
            SiteLink(name: "Боевые искусства", path: "animation/fighting/"),
            SiteLink(name: "Самурайский боевик", path: "animation/samurai/"),
            SiteLink(name: "Спортивные", path: "animation/sport/"),
            SiteLink(name: "Образовательные", path: "animation/educational/"),
            SiteLink(name: "Повседневность", path: "animation/everyday/"),
            SiteLink(name: "Пародия", path: "animation/parody/"),
            SiteLink(name: "Школа", path: "animation/school/"),
            SiteLink(name: "Детские", path: "animation/kids/"),
            SiteLink(name: "Сказки", path: "animation/fairytale/"),
            SiteLink(name: "Кодомо", path: "animation/kodomo/"),
            SiteLink(name: "Сёдзё-ай", path: "animation/shoujoai/"),
            SiteLink(name: "Сёдзё", path: "animation/shoujo/"),
            SiteLink(name: "Сёнэн", path: "animation/shounen/"),
            SiteLink(name: "Сёнэн-ай", path: "animation/shounenai/"),
            SiteLink(name: "Этти", path: "animation/ecchi/"),
            SiteLink(name: "Махо-сёдзё", path: "animation/mahoushoujo/"),
            SiteLink(name: "Меха", path: "animation/mecha/"),
        ], studios: [
            SiteLink(name: "Netflix", path: "collections/1242-anime-netflix/", title: "Аниме Netflix"),
        ]),
    ]
}
