import Foundation
import SwiftSoup

class PeopleParser {
    /// Person page: titles, the info table rows and one movie list per career block.
    func parse(html: String) throws -> PersonDetailed {
        let document = try SwiftSoup.parse(html)
        let nameRu = try document.select("div.b-post__title").select("span.t1").text()
        let nameOrig = try document.getNameOriginal()
        let photo = try document.getPhoto()

        var career = ""
        var birthDate: String?
        var birthPlace: String?
        var deathDate: String?
        var deathPlace: String?
        var height: String?
        for row in try document.select("div.b-post__infotable_right_inner").select("tr") {
            let cells = try row.select("td")
            guard cells.count == 2 else { continue }
            let title = try cells[0].getElementsByTag("h2").text()
            let value = try cells[1].text()
            switch title {
            case "Карьера": career = value
            case "Дата рождения": birthDate = value
            case "Место рождения": birthPlace = value
            case "Дата смерти": deathDate = value
            case "Место смерти": deathPlace = value
            case "Рост": height = value
            default: break
            }
        }

        var actorMovies: [MovieSimple]?
        var directorMovies: [MovieSimple]?
        var producerMovies: [MovieSimple]?
        var screenwriterMovies: [MovieSimple]?
        var operatorMovies: [MovieSimple]?
        var editorMovies: [MovieSimple]?
        var artistMovies: [MovieSimple]?
        for block in try document.select("div.b-person__career") {
            let title = try block.getElementsByTag("h2").text()
            let movies = try block.select("div.b-content__inline_item")
            switch title {
            case "Режиссер": directorMovies = try movies.parseMovies()
            case "Актер": actorMovies = try movies.parseMovies()
            case "Продюсер": producerMovies = try movies.parseMovies()
            case "Сценарист": screenwriterMovies = try movies.parseMovies()
            case "Оператор": operatorMovies = try movies.parseMovies()
            case "Монтажер": editorMovies = try movies.parseMovies()
            case "Художник": artistMovies = try movies.parseMovies()
            case "Актриса": actorMovies = try movies.parseMovies()
            default: break
            }
        }

        return PersonDetailed(nameRu: nameRu, nameOrig: nameOrig, photo: photo, career: career,
                              birthDate: birthDate, birthPlace: birthPlace, deathDate: deathDate,
                              deathPlace: deathPlace, height: height, actorMovies: actorMovies,
                              directorMovies: directorMovies, producerMovies: producerMovies,
                              screenwriterMovies: screenwriterMovies, operatorMovies: operatorMovies,
                              editorMovies: editorMovies, artistMovies: artistMovies)
    }
}

class PeopleRepository {
    /// `id` may come as "person/4176-vudi-harrelson/": only the slug goes into the URL.
    func getPersonDetails(id: String) async throws -> PersonDetailed {
        let network = PeopleNetwork()  // built before the slug, as at 0x1000f65d4
        let html = try await network.getPersonDetails(id: Self.slug(id))
        return try PeopleParser().parse(html: html)
    }

    /// Drops "person/" and then every "/": "person/4176-vudi-harrelson/" -> "4176-vudi-harrelson".
    static func slug(_ id: String) -> String {
        id.replacingOccurrences(of: "person/", with: "").replacingOccurrences(of: "/", with: "")
    }
}

private extension Document {
    func getNameOriginal() throws -> String? {
        let name = try select("div.b-post__title").select("span.t2")
        if name.isEmpty() {
            return nil
        }
        return try name.text()
    }

    func getPhoto() throws -> String {
        try select("div.b-post__infotable_left").select("div.b-sidecover").first!.getElementsByTag("img").attr("src")
    }
}

private extension Elements {
    /// Career block cards; the id is the cover link (an absolute page URL).
    func parseMovies() throws -> [MovieSimple] {
        try map { element in
            let id = try element.select("div.b-content__inline_item-cover").first!.getElementsByTag("a").first!.attr("href")
            let name = try element.select("div.b-content__inline_item-link").first!.getElementsByTag("a").first!.text()
            let details = try element.select("div.b-content__inline_item-link").first!.select("div.misc").first!.text()
            let poster = try element.select("div.b-content__inline_item-cover").first!.getElementsByTag("a").first!
                .getElementsByTag("img").first!.attr("src")
            return MovieSimple(id: id, name: name, details: details, poster: poster)
        }
    }
}
