import Foundation
import AppKit

// MARK: - Config

struct Config {
    // ЗДЕСЬ ДОЛЖЕН БЫТЬ ТВОЙ URL к папке с картинками на GitHub
    // Пример:
    // https://raw.githubusercontent.com/USERNAME/daily-wallpapers/main/wallpapers
    static let baseURL = URL(string: "https://raw.githubusercontent.com/ruzvaliakhmetov/daily-wallpapers/main/wallpapers")!

    // Имя fallback-картинки в репозитории
    static let fallbackFileName = "fallback.jpg"

    static let fileManager = FileManager.default
}

// MARK: - Helpers

func todayString() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")

    // Если хочешь, чтобы у всех была одна дата по UTC:
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    // Если хочешь по локальному времени мака, можно так:
    // formatter.timeZone = .current

    formatter.dateFormat = "yyyy-MM-dd"
    let result = formatter.string(from: Date())
    print("Today is \(result)")
    return result
}

enum WallpaperError: Error {
    case downloadFailed(String)
    case setWallpaperFailed(String)
}

func downloadImage(from remoteURL: URL, localName: String) throws -> URL {
    print("Trying to download: \(remoteURL.absoluteString)")

    let data: Data
    do {
        data = try Data(contentsOf: remoteURL)
    } catch {
        throw WallpaperError.downloadFailed("Failed to load data from \(remoteURL): \(error)")
    }

    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let localURL = tmpDir.appendingPathComponent(localName)

    do {
        try data.write(to: localURL, options: [.atomic])
    } catch {
        throw WallpaperError.downloadFailed("Failed to write file to \(localURL.path): \(error)")
    }

    print("Saved image to temp: \(localURL.path)")
    return localURL
}

/// Пытаемся скачать картинку по дате, если не получилось — пробуем fallback.
/// Если и fallback не удаётся — кидаем ошибку.
func downloadWallpaper(for dateString: String) throws -> URL {
    // Основная картинка по дате
    let primaryURL = Config.baseURL.appendingPathComponent("\(dateString).jpg")

    if let primary = try? downloadImage(
        from: primaryURL,
        localName: "dailywallpaper-\(dateString).jpg"
    ) {
        print("Using primary image for date \(dateString)")
        return primary
    } else {
        print("Primary image for \(dateString) not available, trying fallback...")
    }

    // Fallback
    let fallbackURL = Config.baseURL.appendingPathComponent(Config.fallbackFileName)

    if let fallback = try? downloadImage(
        from: fallbackURL,
        localName: "dailywallpaper-fallback.jpg"
    ) {
        print("Using fallback image")
        return fallback
    }

    throw WallpaperError.downloadFailed("Neither \(primaryURL.lastPathComponent) nor \(Config.fallbackFileName) could be downloaded")
}

func setWallpaper(from localURL: URL) throws {
    let workspace = NSWorkspace.shared
    let screens = NSScreen.screens

    guard !screens.isEmpty else {
        throw WallpaperError.setWallpaperFailed("No screens found")
    }

    for screen in screens {
        do {
            try workspace.setDesktopImageURL(localURL, for: screen, options: [:])
            print("Set wallpaper for screen: \(screen)")
        } catch {
            throw WallpaperError.setWallpaperFailed("Failed to set wallpaper: \(error)")
        }
    }
}

// MARK: - Main

func mainLogic() {
    let today = todayString()

    do {
        let fileURL = try downloadWallpaper(for: today)
        try setWallpaper(from: fileURL)
        print("✅ Wallpaper updated successfully")
    } catch let error as WallpaperError {
        switch error {
        case .downloadFailed(let message):
            fputs("Download failed: \(message)\n", stderr)
        case .setWallpaperFailed(let message):
            fputs("Set wallpaper failed: \(message)\n", stderr)
        }
    } catch {
        fputs("Unexpected error in DailyWallpaper: \(error)\n", stderr)
    }
}

mainLogic()
