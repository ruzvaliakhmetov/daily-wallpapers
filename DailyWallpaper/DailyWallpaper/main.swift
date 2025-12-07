import Foundation
import AppKit

// CONFIG — НЕ ЗАБУДЬ ПОСТАВИТЬ СВОЙ baseURL
struct Config {
    // Пример:
    // https://raw.githubusercontent.com/USERNAME/daily-wallpapers/main/wallpapers
    static let baseURL = URL(string: "https://raw.githubusercontent.com/ruzvaliakhmetov/daily-wallpapers/main/wallpapers/")!

    static let appName = "DailyWallpaper"
    static let fileManager = FileManager.default

    static var appSupportFolder: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    static var stateFile: URL {
        appSupportFolder.appendingPathComponent("state.json")
    }

    // Имя fallback-картинки в репозитории
    static let fallbackFileName = "fallback.jpg"
}

struct State: Codable {
    let lastDate: String
}

func todayString() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")

    // Вариант 1: у всех одна и та же дата по UTC:
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    // Вариант 2: локальное время Mac:
    // formatter.timeZone = .current

    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

func loadState() -> State? {
    let url = Config.stateFile
    guard Config.fileManager.fileExists(atPath: url.path) else { return nil }

    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(State.self, from: data)
    } catch {
        return nil
    }
}

func saveState(_ state: State) {
    do {
        try Config.fileManager.createDirectory(
            at: Config.appSupportFolder,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(state)
        try data.write(to: Config.stateFile, options: [.atomic])
    } catch {
        fputs("Failed to save state: \(error)\n", stderr)
    }
}

enum WallpaperError: Error {
    case downloadFailed(String) // message
}

func downloadImage(from remoteURL: URL, localName: String) throws -> URL {
    let data = try Data(contentsOf: remoteURL)

    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let localURL = tmpDir.appendingPathComponent(localName)
    try data.write(to: localURL, options: [.atomic])

    return localURL
}

/// Скачиваем картинку по дате, если не получилось — пробуем fallback.
/// Если и fallback не доступен — кидаем ошибку.
func downloadWallpaper(for dateString: String) throws -> URL {
    let primaryURL = Config.baseURL.appendingPathComponent("\(dateString).jpg")

    // 1. Пытаемся скачать картинку по дате
    if let primary = try? downloadImage(
        from: primaryURL,
        localName: "dailywallpaper-\(dateString).jpg"
    ) {
        return primary
    }

    // 2. Пытаемся скачать fallback
    let fallbackURL = Config.baseURL.appendingPathComponent(Config.fallbackFileName)
    if let fallback = try? downloadImage(
        from: fallbackURL,
        localName: "dailywallpaper-fallback.jpg"
    ) {
        return fallback
    }

    throw WallpaperError.downloadFailed("Neither \(primaryURL.lastPathComponent) nor fallback found")
}

func setWallpaper(from localURL: URL) throws {
    let workspace = NSWorkspace.shared

    for screen in NSScreen.screens {
        try workspace.setDesktopImageURL(localURL, for: screen, options: [:])
    }
}

func mainLogic() {
    let today = todayString()

    // Если уже меняли обои сегодня — выходим
    if let state = loadState(), state.lastDate == today {
        return
    }

    do {
        let fileURL = try downloadWallpaper(for: today)
        try setWallpaper(from: fileURL)

        saveState(State(lastDate: today))
    } catch let error as WallpaperError {
        switch error {
        case .downloadFailed(let message):
            fputs("Download failed: \(message)\n", stderr)
        }
    } catch {
        fputs("Error in DailyWallpaper: \(error)\n", stderr)
    }

    // После выхода из mainLogic программа завершится сама
}

mainLogic()
