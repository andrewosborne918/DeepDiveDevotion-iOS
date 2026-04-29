import Foundation

// MARK: - Supporting Types

enum PlanCategory: String, CaseIterable, Identifiable {
    case quickStart  = "Quick Start"
    case fullBible   = "Complete Bible"
    case timeBased   = "Time-Based"
    case topics      = "Topics"
    case narrative   = "Stories"
    case challenges  = "Challenges"
    case habits      = "Daily Habits"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .quickStart: return "bolt.fill"
        case .fullBible:  return "books.vertical.fill"
        case .timeBased:  return "calendar"
        case .topics:     return "heart.fill"
        case .narrative:  return "book.fill"
        case .challenges: return "flame.fill"
        case .habits:     return "sun.max.fill"
        }
    }
}

enum PlanDifficulty: String {
    case light    = "Light"
    case moderate = "Moderate"
    case deep     = "Deep"
}

struct PlanStep: Identifiable {
    let id: String
    let dayNumber: Int
    let title: String
    let bookName: String
    let chapterNumber: Int?

    init(planId: String, day: Int, title: String, book: String, chapter: Int? = nil) {
        self.id            = "\(planId)-day\(day)"
        self.dayNumber     = day
        self.title         = title
        self.bookName      = book
        self.chapterNumber = chapter
    }
}

struct ReadingPlan: Identifiable {
    let id: String
    let title: String
    let subtitle: String   // short line under title (detail view header)
    let hook: String       // one-line emotional hook shown on cards
    let category: PlanCategory
    let durationLabel: String
    let dailyTimeLabel: String
    let difficulty: PlanDifficulty
    let description: String
    let steps: [PlanStep]

    var totalDays: Int { steps.count }
}

// MARK: - All Curated Plans

extension ReadingPlan {

    // MARK: Shared book data

    /// (bookName, chapterCount)
    static let otBooks: [(String, Int)] = [
        ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34),
        ("Joshua", 24), ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24),
        ("1 Kings", 22), ("2 Kings", 25), ("1 Chronicles", 29), ("2 Chronicles", 36),
        ("Ezra", 10), ("Nehemiah", 13), ("Esther", 10), ("Job", 42), ("Psalms", 150),
        ("Proverbs", 31), ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66),
        ("Jeremiah", 52), ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12),
        ("Hosea", 14), ("Joel", 3), ("Amos", 9), ("Obadiah", 1), ("Jonah", 4),
        ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3),
        ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4),
    ]

    static let ntBooks: [(String, Int)] = [
        ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21), ("Acts", 28),
        ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6),
        ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4),
        ("1 Thessalonians", 5), ("2 Thessalonians", 3),
        ("1 Timothy", 6), ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1),
        ("Hebrews", 13), ("James", 5), ("1 Peter", 5), ("2 Peter", 3),
        ("1 John", 5), ("2 John", 1), ("3 John", 1), ("Jude", 1), ("Revelation", 22),
    ]

    private static func stepsFrom(planId: String, books: [(String, Int)], startingDay: Int = 1) -> [PlanStep] {
        var steps: [PlanStep] = []
        var day = startingDay
        for (book, chapters) in books {
            for chapter in 1...chapters {
                steps.append(PlanStep(planId: planId, day: day, title: "\(book) \(chapter)", book: book, chapter: chapter))
                day += 1
            }
        }
        return steps
    }

    static let all: [ReadingPlan] = [
        sevenDayStart,
        fullBible,
        fullOldTestament,
        fullNewTestament,
        thirtyDayNT,
        lifeOfJesus,
        earlyChurch,
        anxietyAndPeace,
        purposeAndCalling,
        faithInHardTimes,
        identityInChrist,
        forgiveness,
        sevenDayPrayer,
        twentyOneDayDiscipline,
        dailyWisdom,
    ]

    static func plans(for category: PlanCategory) -> [ReadingPlan] {
        all.filter { $0.category == category }
    }

    // MARK: Complete Bible Plans

    static let fullOldTestament = ReadingPlan(
        id: "full-ot",
        title: "Old Testament",
        subtitle: "All 929 chapters in order",
        hook: "The complete OT — Genesis to Malachi",
        category: .fullBible,
        durationLabel: "929 days",
        dailyTimeLabel: "10–15 min/day",
        difficulty: .deep,
        description: "Every chapter of the Old Testament in canonical order — from Creation in Genesis through the prophets to Malachi. One chapter per day, straight through.",
        steps: stepsFrom(planId: "full-ot", books: otBooks)
    )

    static let fullNewTestament = ReadingPlan(
        id: "full-nt",
        title: "New Testament",
        subtitle: "All 260 chapters in order",
        hook: "The complete NT — Matthew to Revelation",
        category: .fullBible,
        durationLabel: "260 days",
        dailyTimeLabel: "10–15 min/day",
        difficulty: .moderate,
        description: "Every chapter of the New Testament in canonical order — from the birth of Jesus in Matthew to the new creation in Revelation. One chapter per day.",
        steps: stepsFrom(planId: "full-nt", books: ntBooks)
    )

    static let fullBible = ReadingPlan(
        id: "full-bible",
        title: "Full Bible",
        subtitle: "OT then NT — all 1,189 chapters",
        hook: "Read the entire Bible, cover to cover",
        category: .fullBible,
        durationLabel: "1,189 days",
        dailyTimeLabel: "10–15 min/day",
        difficulty: .deep,
        description: "The complete Bible in canonical order — all 929 chapters of the Old Testament followed by all 260 chapters of the New Testament. One chapter per day, start to finish.",
        steps: stepsFrom(planId: "full-bible", books: otBooks + ntBooks)
    )

    // MARK: Quick Start

    static let sevenDayStart = ReadingPlan(
        id: "7day-start",
        title: "7-Day Quick Start",
        subtitle: "Begin your journey",
        hook: "Your best first week in Scripture",
        category: .quickStart,
        durationLabel: "7 days",
        dailyTimeLabel: "10 min/day",
        difficulty: .light,
        description: "New to the app? This week-long plan introduces you to the heart of the Bible — from the Psalms to the Gospels to Paul's letters. A perfect first week.",
        steps: [
            PlanStep(planId: "7day-start", day: 1, title: "Psalms 23 — The Lord Is My Shepherd",         book: "Psalms",      chapter: 23),
            PlanStep(planId: "7day-start", day: 2, title: "John 1 — In the Beginning Was the Word",      book: "John",        chapter: 1),
            PlanStep(planId: "7day-start", day: 3, title: "John 3 — You Must Be Born Again",             book: "John",        chapter: 3),
            PlanStep(planId: "7day-start", day: 4, title: "Romans 8 — No Condemnation",                  book: "Romans",      chapter: 8),
            PlanStep(planId: "7day-start", day: 5, title: "Matthew 5 — The Sermon on the Mount",         book: "Matthew",     chapter: 5),
            PlanStep(planId: "7day-start", day: 6, title: "Philippians 4 — The Peace That Passes Understanding", book: "Philippians", chapter: 4),
            PlanStep(planId: "7day-start", day: 7, title: "Revelation 21 — All Things New",              book: "Revelation",  chapter: 21),
        ]
    )

    // MARK: Time-Based

    static let thirtyDayNT = ReadingPlan(
        id: "30day-nt",
        title: "30-Day New Testament",
        subtitle: "The full NT story in a month",
        hook: "Know the whole story of Jesus in a month",
        category: .timeBased,
        durationLabel: "30 days",
        dailyTimeLabel: "15 min/day",
        difficulty: .moderate,
        description: "Walk through the New Testament in 30 key chapters — from the birth of Jesus in Matthew to the vision of the new creation in Revelation.",
        steps: {
            let entries: [(String, Int)] = [
                ("Matthew", 1), ("Matthew", 5), ("Matthew", 6), ("Matthew", 26), ("Matthew", 28),
                ("Mark", 1), ("Mark", 10), ("Mark", 16),
                ("Luke", 1), ("Luke", 2), ("Luke", 15), ("Luke", 22), ("Luke", 24),
                ("John", 1), ("John", 3), ("John", 11), ("John", 14), ("John", 20),
                ("Acts", 1), ("Acts", 2), ("Acts", 9), ("Acts", 13),
                ("Romans", 5), ("Romans", 8), ("Romans", 12),
                ("1 Corinthians", 13), ("Ephesians", 2), ("Philippians", 4),
                ("Hebrews", 11), ("Revelation", 21),
            ]
            return entries.enumerated().map { i, e in
                PlanStep(planId: "30day-nt", day: i + 1, title: "\(e.0) \(e.1)", book: e.0, chapter: e.1)
            }
        }()
    )

    // MARK: Narrative

    static let lifeOfJesus = ReadingPlan(
        id: "life-of-jesus",
        title: "The Life of Jesus",
        subtitle: "Birth to resurrection",
        hook: "Walk with Jesus from birth to resurrection",
        category: .narrative,
        durationLabel: "12 days",
        dailyTimeLabel: "15 min/day",
        difficulty: .light,
        description: "Follow Jesus from birth to resurrection in 12 key chapters — each one chosen to tell the complete story of His life, ministry, and mission.",
        steps: [
            PlanStep(planId: "life-of-jesus", day: 1,  title: "Luke 1 — The Annunciation",               book: "Luke",    chapter: 1),
            PlanStep(planId: "life-of-jesus", day: 2,  title: "Luke 2 — The Birth of Jesus",             book: "Luke",    chapter: 2),
            PlanStep(planId: "life-of-jesus", day: 3,  title: "Matthew 3 — The Baptism",                 book: "Matthew", chapter: 3),
            PlanStep(planId: "life-of-jesus", day: 4,  title: "Matthew 4 — The Temptation",              book: "Matthew", chapter: 4),
            PlanStep(planId: "life-of-jesus", day: 5,  title: "Matthew 5 — Sermon on the Mount",         book: "Matthew", chapter: 5),
            PlanStep(planId: "life-of-jesus", day: 6,  title: "John 2 — The First Miracle",              book: "John",    chapter: 2),
            PlanStep(planId: "life-of-jesus", day: 7,  title: "John 6 — Bread of Life",                  book: "John",    chapter: 6),
            PlanStep(planId: "life-of-jesus", day: 8,  title: "John 11 — The Resurrection of Lazarus",   book: "John",    chapter: 11),
            PlanStep(planId: "life-of-jesus", day: 9,  title: "John 14 — I Am the Way",                  book: "John",    chapter: 14),
            PlanStep(planId: "life-of-jesus", day: 10, title: "Luke 22 — The Last Supper",               book: "Luke",    chapter: 22),
            PlanStep(planId: "life-of-jesus", day: 11, title: "John 19 — The Crucifixion",               book: "John",    chapter: 19),
            PlanStep(planId: "life-of-jesus", day: 12, title: "John 20 — The Resurrection",              book: "John",    chapter: 20),
        ]
    )

    static let earlyChurch = ReadingPlan(
        id: "early-church",
        title: "The Early Church",
        subtitle: "Acts & the birth of Christianity",
        hook: "Watch the church explode from 12 to thousands",
        category: .narrative,
        durationLabel: "8 days",
        dailyTimeLabel: "15 min/day",
        difficulty: .moderate,
        description: "Trace the explosive growth of the early church from Pentecost to Paul's final journey to Rome. Bingeable and story-driven.",
        steps: [
            PlanStep(planId: "early-church", day: 1, title: "Acts 1 — The Great Commission",          book: "Acts", chapter: 1),
            PlanStep(planId: "early-church", day: 2, title: "Acts 2 — Pentecost",                     book: "Acts", chapter: 2),
            PlanStep(planId: "early-church", day: 3, title: "Acts 7 — Stephen's Speech",              book: "Acts", chapter: 7),
            PlanStep(planId: "early-church", day: 4, title: "Acts 9 — Paul's Conversion",             book: "Acts", chapter: 9),
            PlanStep(planId: "early-church", day: 5, title: "Acts 13 — First Missionary Journey",     book: "Acts", chapter: 13),
            PlanStep(planId: "early-church", day: 6, title: "Acts 15 — The Jerusalem Council",        book: "Acts", chapter: 15),
            PlanStep(planId: "early-church", day: 7, title: "Acts 17 — Athens & the Unknown God",     book: "Acts", chapter: 17),
            PlanStep(planId: "early-church", day: 8, title: "Acts 28 — Rome",                         book: "Acts", chapter: 28),
        ]
    )

    // MARK: Topics

    static let anxietyAndPeace = ReadingPlan(
        id: "anxiety-peace",
        title: "Anxiety & Peace",
        subtitle: "Find rest in Scripture",
        hook: "Calm your mind and trust God again",
        category: .topics,
        durationLabel: "8 days",
        dailyTimeLabel: "10 min/day",
        difficulty: .light,
        description: "Eight passages hand-picked to quiet an anxious heart and anchor you in the peace that passes all understanding.",
        steps: [
            PlanStep(planId: "anxiety-peace", day: 1, title: "Psalms 23 — The Lord Is My Shepherd",          book: "Psalms",      chapter: 23),
            PlanStep(planId: "anxiety-peace", day: 2, title: "Psalms 46 — God Is Our Refuge",               book: "Psalms",      chapter: 46),
            PlanStep(planId: "anxiety-peace", day: 3, title: "Psalms 91 — Dwelling in the Shadow",          book: "Psalms",      chapter: 91),
            PlanStep(planId: "anxiety-peace", day: 4, title: "Isaiah 40 — He Gives Strength to the Weary",  book: "Isaiah",      chapter: 40),
            PlanStep(planId: "anxiety-peace", day: 5, title: "Matthew 6 — Do Not Worry",                    book: "Matthew",     chapter: 6),
            PlanStep(planId: "anxiety-peace", day: 6, title: "John 14 — Do Not Let Your Hearts Be Troubled",book: "John",        chapter: 14),
            PlanStep(planId: "anxiety-peace", day: 7, title: "Philippians 4 — The Peace of God",            book: "Philippians", chapter: 4),
            PlanStep(planId: "anxiety-peace", day: 8, title: "1 Peter 5 — Cast Your Anxiety on Him",        book: "1 Peter",     chapter: 5),
        ]
    )

    static let purposeAndCalling = ReadingPlan(
        id: "purpose-calling",
        title: "Purpose & Calling",
        subtitle: "Discover why you're here",
        hook: "Finally understand why you're here",
        category: .topics,
        durationLabel: "7 days",
        dailyTimeLabel: "12 min/day",
        difficulty: .moderate,
        description: "Seven passages that answer the deepest question — why am I here? — through the lens of Scripture and God's unfolding plan.",
        steps: [
            PlanStep(planId: "purpose-calling", day: 1, title: "Jeremiah 1 — Before I Formed You",          book: "Jeremiah",    chapter: 1),
            PlanStep(planId: "purpose-calling", day: 2, title: "Psalms 139 — Fearfully & Wonderfully Made", book: "Psalms",      chapter: 139),
            PlanStep(planId: "purpose-calling", day: 3, title: "Isaiah 43 — You Are Mine",                  book: "Isaiah",      chapter: 43),
            PlanStep(planId: "purpose-calling", day: 4, title: "Romans 12 — Living Sacrifices",             book: "Romans",      chapter: 12),
            PlanStep(planId: "purpose-calling", day: 5, title: "Ephesians 2 — Created for Good Works",      book: "Ephesians",   chapter: 2),
            PlanStep(planId: "purpose-calling", day: 6, title: "Proverbs 3 — Trust in the Lord",            book: "Proverbs",    chapter: 3),
            PlanStep(planId: "purpose-calling", day: 7, title: "Matthew 28 — The Great Commission",         book: "Matthew",     chapter: 28),
        ]
    )

    static let faithInHardTimes = ReadingPlan(
        id: "faith-hard-times",
        title: "Faith in Hard Times",
        subtitle: "Anchored when life is hard",
        hook: "Stay anchored when nothing makes sense",
        category: .topics,
        durationLabel: "7 days",
        dailyTimeLabel: "15 min/day",
        difficulty: .deep,
        description: "When life doesn't make sense, these seven chapters have carried believers through the darkest seasons. Honest, raw, and hopeful.",
        steps: [
            PlanStep(planId: "faith-hard-times", day: 1, title: "Job 1 — The Test Begins",                        book: "Job",      chapter: 1),
            PlanStep(planId: "faith-hard-times", day: 2, title: "Psalms 22 — My God, Why Have You Forsaken Me?",  book: "Psalms",   chapter: 22),
            PlanStep(planId: "faith-hard-times", day: 3, title: "Isaiah 40 — He Gives Strength to the Weary",   book: "Isaiah",   chapter: 40),
            PlanStep(planId: "faith-hard-times", day: 4, title: "Habakkuk 1 — How Long, Lord?",                  book: "Habakkuk", chapter: 1),
            PlanStep(planId: "faith-hard-times", day: 5, title: "Romans 5 — Suffering Produces Hope",            book: "Romans",   chapter: 5),
            PlanStep(planId: "faith-hard-times", day: 6, title: "James 1 — The Testing of Your Faith",           book: "James",    chapter: 1),
            PlanStep(planId: "faith-hard-times", day: 7, title: "1 Peter 5 — Cast Your Anxiety on Him",          book: "1 Peter",  chapter: 5),
        ]
    )

    static let identityInChrist = ReadingPlan(
        id: "identity-christ",
        title: "Identity in Christ",
        subtitle: "Know who you truly are",
        hook: "Know who God says you are — for real",
        category: .topics,
        durationLabel: "7 days",
        dailyTimeLabel: "12 min/day",
        difficulty: .moderate,
        description: "Who are you, really? These seven passages define your identity not by what you do or feel, but by who God says you are in Christ.",
        steps: [
            PlanStep(planId: "identity-christ", day: 1, title: "Genesis 1 — Made in God's Image",       book: "Genesis",    chapter: 1),
            PlanStep(planId: "identity-christ", day: 2, title: "Psalms 139 — You Are Fully Known",      book: "Psalms",     chapter: 139),
            PlanStep(planId: "identity-christ", day: 3, title: "John 1 — Children of God",              book: "John",       chapter: 1),
            PlanStep(planId: "identity-christ", day: 4, title: "Romans 8 — More Than Conquerors",       book: "Romans",     chapter: 8),
            PlanStep(planId: "identity-christ", day: 5, title: "Ephesians 1 — Blessed in Christ",       book: "Ephesians",  chapter: 1),
            PlanStep(planId: "identity-christ", day: 6, title: "Galatians 3 — All One in Christ",       book: "Galatians",  chapter: 3),
            PlanStep(planId: "identity-christ", day: 7, title: "1 John 3 — Children of God Now",        book: "1 John",     chapter: 3),
        ]
    )

    static let forgiveness = ReadingPlan(
        id: "forgiveness",
        title: "Forgiveness",
        subtitle: "Release what you're holding",
        hook: "Release what you've been holding onto",
        category: .topics,
        durationLabel: "6 days",
        dailyTimeLabel: "12 min/day",
        difficulty: .moderate,
        description: "Six chapters on the most liberating act in Scripture — from Joseph's reunion with his brothers to Jesus' command to forgive seventy times seven.",
        steps: [
            PlanStep(planId: "forgiveness", day: 1, title: "Genesis 45 — Joseph Forgives His Brothers",    book: "Genesis",    chapter: 45),
            PlanStep(planId: "forgiveness", day: 2, title: "Psalms 51 — Create in Me a Clean Heart",       book: "Psalms",     chapter: 51),
            PlanStep(planId: "forgiveness", day: 3, title: "Luke 15 — The Prodigal Son",                   book: "Luke",       chapter: 15),
            PlanStep(planId: "forgiveness", day: 4, title: "Matthew 18 — Seventy Times Seven",             book: "Matthew",    chapter: 18),
            PlanStep(planId: "forgiveness", day: 5, title: "Ephesians 4 — Be Kind and Forgiving",          book: "Ephesians",  chapter: 4),
            PlanStep(planId: "forgiveness", day: 6, title: "Colossians 3 — Forgive as the Lord Forgave",   book: "Colossians", chapter: 3),
        ]
    )

    // MARK: Challenges

    static let sevenDayPrayer = ReadingPlan(
        id: "7day-prayer",
        title: "7-Day Prayer Challenge",
        subtitle: "Learn to pray through Scripture",
        hook: "Transform your prayer life in a week",
        category: .challenges,
        durationLabel: "7 days",
        dailyTimeLabel: "10 min/day",
        difficulty: .light,
        description: "Seven chapters on prayer — from Jesus teaching the Lord's Prayer to Daniel's great intercession. By the end of this week, you'll pray differently.",
        steps: [
            PlanStep(planId: "7day-prayer", day: 1, title: "Matthew 6 — The Lord's Prayer",              book: "Matthew",          chapter: 6),
            PlanStep(planId: "7day-prayer", day: 2, title: "Luke 11 — Ask, Seek, Knock",                 book: "Luke",             chapter: 11),
            PlanStep(planId: "7day-prayer", day: 3, title: "Psalms 5 — Morning Prayer",                  book: "Psalms",           chapter: 5),
            PlanStep(planId: "7day-prayer", day: 4, title: "Psalms 51 — A Prayer of Confession",         book: "Psalms",           chapter: 51),
            PlanStep(planId: "7day-prayer", day: 5, title: "Daniel 9 — Daniel's Great Intercession",     book: "Daniel",           chapter: 9),
            PlanStep(planId: "7day-prayer", day: 6, title: "Acts 4 — The Church's Bold Prayer",          book: "Acts",             chapter: 4),
            PlanStep(planId: "7day-prayer", day: 7, title: "1 Thessalonians 5 — Pray Without Ceasing",   book: "1 Thessalonians",  chapter: 5),
        ]
    )

    static let twentyOneDayDiscipline = ReadingPlan(
        id: "21day-discipline",
        title: "21-Day Discipline Builder",
        subtitle: "Build the daily habit in 3 weeks",
        hook: "Build the habit that changes everything",
        category: .challenges,
        durationLabel: "21 days",
        dailyTimeLabel: "10 min/day",
        difficulty: .moderate,
        description: "Studies show habits form in 21 days. This plan alternates Psalms with short NT passages to help you lock in a daily devotion rhythm.",
        steps: {
            let psalms = [1, 8, 19, 23, 27, 34, 46, 51, 63, 91, 103, 121, 139, 145, 150]
            let nt: [(String, Int)] = [
                ("Matthew", 5), ("Romans", 8), ("Philippians", 4),
                ("James", 1), ("Hebrews", 11), ("Galatians", 5),
            ]
            var steps: [PlanStep] = []
            for (i, psalm) in psalms.enumerated() {
                steps.append(PlanStep(planId: "21day-discipline", day: i + 1,
                    title: "Psalms \(psalm)", book: "Psalms", chapter: psalm))
            }
            for (i, entry) in nt.enumerated() {
                steps.append(PlanStep(planId: "21day-discipline", day: psalms.count + i + 1,
                    title: "\(entry.0) \(entry.1)", book: entry.0, chapter: entry.1))
            }
            return steps
        }()
    )

    // MARK: Habits

    static let dailyWisdom = ReadingPlan(
        id: "daily-wisdom",
        title: "Daily Wisdom",
        subtitle: "Psalms & Proverbs rotation",
        hook: "Start each day grounded and clear",
        category: .habits,
        durationLabel: "14 days",
        dailyTimeLabel: "7 min/day",
        difficulty: .light,
        description: "A two-week rotation through the greatest wisdom literature in the Bible — one Psalm and one chapter of Proverbs, alternating daily.",
        steps: {
            let psalms   = [1, 8, 19, 23, 34, 91, 103]
            let proverbs = [1, 2, 3, 4, 8, 16, 31]
            var steps: [PlanStep] = []
            for i in 0..<7 {
                let day = i * 2 + 1
                steps.append(PlanStep(planId: "daily-wisdom", day: day,
                    title: "Psalms \(psalms[i])", book: "Psalms", chapter: psalms[i]))
                steps.append(PlanStep(planId: "daily-wisdom", day: day + 1,
                    title: "Proverbs \(proverbs[i])", book: "Proverbs", chapter: proverbs[i]))
            }
            return steps.sorted { $0.dayNumber < $1.dayNumber }
        }()
    )
}
