import Foundation

/// Comprehensive Bible vocabulary data for speech recognition and detection
enum BibleVocabularyData {
    
    // MARK: - All 66 Books with Canonical Names
    
    static let allBooks: [String] = [
        // Old Testament (39 books)
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
        "Ezra", "Nehemiah", "Esther", "Job", "Psalms",
        "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
        "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
        "Amos", "Obadiah", "Jonah", "Micah", "Nahum",
        "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
        
        // New Testament (27 books)
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
        "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
        "James", "1 Peter", "2 Peter", "1 John", "2 John",
        "3 John", "Jude", "Revelation"
    ]
    
    // MARK: - Comprehensive Mappings (STT Mishearings)
    
    /// Maps common speech-to-text errors to canonical book names
    static let sttMishearings: [String: String] = [
        // Genesis
        "genesis": "Genesis",
        "jen-uh-sis": "Genesis",
        "jennesis": "Genesis",
        "jenisis": "Genesis",
        
        // Exodus
        "exodus": "Exodus",
        "x-odus": "Exodus",
        
        // Leviticus
        "leviticus": "Leviticus",
        "leviticus's": "Leviticus",
        "la viticus": "Leviticus",
        
        // Numbers
        "numbers": "Numbers",
        
        // Deuteronomy
        "deuteronomy": "Deuteronomy",
        "due-ter-on-oh-me": "Deuteronomy",
        "do to ronomy": "Deuteronomy",
        "deuteronomy's": "Deuteronomy",
        
        // Joshua
        "joshua": "Joshua",
        "josh-you-a": "Joshua",
        
        // Judges
        "judges": "Judges",
        
        // Ruth
        "ruth": "Ruth",
        
        // Samuel
        "samuel": "1 Samuel",
        "1 samuel": "1 Samuel",
        "2 samuel": "2 Samuel",
        "first samuel": "1 Samuel",
        "second samuel": "2 Samuel",
        "1st samuel": "1 Samuel",
        "2nd samuel": "2 Samuel",
        
        // Kings
        "kings": "1 Kings",
        "1 kings": "1 Kings",
        "2 kings": "2 Kings",
        "first kings": "1 Kings",
        "second kings": "2 Kings",
        "1st kings": "1 Kings",
        "2nd kings": "2 Kings",
        
        // Chronicles
        "chronicles": "1 Chronicles",
        "1 chronicles": "1 Chronicles",
        "2 chronicles": "2 Chronicles",
        "first chronicles": "1 Chronicles",
        "second chronicles": "2 Chronicles",
        
        // Ezra
        "ezra": "Ezra",
        "as raw": "Ezra",
        
        // Nehemiah
        "nehemiah": "Nehemiah",
        "knee a my a": "Nehemiah",
        "nee uh my uh": "Nehemiah",
        "knee a mia": "Nehemiah",
        
        // Esther
        "esther": "Esther",
        "ester": "Esther",
        
        // Job
        "job": "Job",
        "jobe": "Job",
        
        // Psalms
        "psalm": "Psalms",
        "psalms": "Psalms",
        "songs": "Psalms",
        "sum": "Psalms",
        "sums": "Psalms",
        
        // Proverbs
        "proverbs": "Proverbs",
        "proverb": "Proverbs",
        "probvers": "Proverbs",
        
        // Ecclesiastes
        "ecclesiastes": "Ecclesiastes",
        "ek-lee-zee-as-tees": "Ecclesiastes",
        "ecclesia-stees": "Ecclesiastes",
        "ecclesiastical": "Ecclesiastes",
        
        // Song of Solomon
        "song of solomon": "Song of Solomon",
        "song of songs": "Song of Solomon",
        "songs of solomon": "Song of Solomon",
        "solomon's song": "Song of Solomon",
        
        // Isaiah
        "isaiah": "Isaiah",
        "eye-zay-uh": "Isaiah",
        "isaiaha": "Isaiah",
        
        // Jeremiah
        "jeremiah": "Jeremiah",
        "jer-uh-my-uh": "Jeremiah",
        "jerimiah": "Jeremiah",
        "jeramiah": "Jeremiah",
        
        // Lamentations
        "lamentations": "Lamentations",
        "lamentation": "Lamentations",
        "la-men-tay-shuns": "Lamentations",
        
        // Ezekiel
        "ezekiel": "Ezekiel",
        "ee-zeek-ee-el": "Ezekiel",
        "ezequiel": "Ezekiel",
        
        // Daniel
        "daniel": "Daniel",
        
        // Hosea
        "hosea": "Hosea",
        "hose-ay-uh": "Hosea",
        "jose a": "Hosea",
        
        // Joel
        "joel": "Joel",
        "joe el": "Joel",
        
        // Amos
        "amos": "Amos",
        "ay-mos": "Amos",
        
        // Obadiah
        "obadiah": "Obadiah",
        "oh-buh-dy-uh": "Obadiah",
        "obed ayah": "Obadiah",
        
        // Jonah
        "jonah": "Jonah",
        "joe-nuh": "Jonah",
        
        // Micah
        "micah": "Micah",
        "my-kuh": "Micah",
        "mike a": "Micah",
        
        // Nahum
        "nahum": "Nahum",
        "nay-hum": "Nahum",
        "name": "Nahum",
        
        // Habakkuk
        "habakkuk": "Habakkuk",
        "huh-bak-kuk": "Habakkuk",
        "ha back cook": "Habakkuk",
        "havoc cook": "Habakkuk",
        
        // Zephaniah
        "zephaniah": "Zephaniah",
        "zef-uh-ny-uh": "Zephaniah",
        "stephania": "Zephaniah",
        
        // Haggai
        "haggai": "Haggai",
        "hag-eye": "Haggai",
        "hag i": "Haggai",
        
        // Zechariah
        "zechariah": "Zechariah",
        "zek-uh-ry-uh": "Zechariah",
        "zachariah": "Zechariah",
        
        // Malachi
        "malachi": "Malachi",
        "mal-uh-ky": "Malachi",
        "malachite": "Malachi",
        
        // Matthew
        "matthew": "Matthew",
        "mathew": "Matthew",
        
        // Mark
        "mark": "Mark",
        
        // Luke
        "luke": "Luke",
        
        // John
        "john": "John",
        "jon": "John",
        "1 john": "1 John",
        "2 john": "2 John",
        "3 john": "3 John",
        "first john": "1 John",
        "second john": "2 John",
        "third john": "3 John",
        
        // Acts
        "acts": "Acts",
        "acts of the apostles": "Acts",
        "axe": "Acts",
        
        // Romans
        "romans": "Romans",
        "roman": "Romans",
        
        // Corinthians
        "corinthians": "1 Corinthians",
        "1 corinthians": "1 Corinthians",
        "2 corinthians": "2 Corinthians",
        "first corinthians": "1 Corinthians",
        "second corinthians": "2 Corinthians",
        "korin-thians": "1 Corinthians",
        
        // Galatians
        "galatians": "Galatians",
        "gah-lay-shuns": "Galatians",
        "glacians": "Galatians",
        "galatia": "Galatians",
        
        // Ephesians
        "ephesians": "Ephesians",
        "ephesian": "Ephesians",
        "uh-fee-zhuns": "Ephesians",
        "fusions": "Ephesians",
        "a fusions": "Ephesians",
        
        // Philippians
        "philippians": "Philippians",
        "filipinos": "Philippians",
        "filipino": "Philippians",
        "philipians": "Philippians",
        "phillipians": "Philippians",
        "philippines": "Philippians",
        "philippine": "Philippians",
        "fill up in": "Philippians",
        "fill a pin": "Philippians",
        
        // Colossians
        "colossians": "Colossians",
        "kuh-losh-unz": "Colossians",
        "cautions": "Colossians",
        "closions": "Colossians",
        "collision": "Colossians",
        
        // Thessalonians
        "thessalonians": "1 Thessalonians",
        "1 thessalonians": "1 Thessalonians",
        "2 thessalonians": "2 Thessalonians",
        "first thessalonians": "1 Thessalonians",
        "second thessalonians": "2 Thessalonians",
        "thessalonian": "1 Thessalonians",
        "the saloni": "1 Thessalonians",
        "the salonika": "1 Thessalonians",
        "thess-uh-loan-ee-unz": "1 Thessalonians",
        
        // Timothy
        "timothy": "1 Timothy",
        "1 timothy": "1 Timothy",
        "2 timothy": "2 Timothy",
        "first timothy": "1 Timothy",
        "second timothy": "2 Timothy",
        
        // Titus
        "titus": "Titus",
        "tie-tus": "Titus",
        
        // Philemon
        "philemon": "Philemon",
        "fuh-lee-mun": "Philemon",
        "fly-mon": "Philemon",
        "file-mon": "Philemon",
        
        // Hebrews
        "hebrews": "Hebrews",
        "hebrew": "Hebrews",
        "he-brooz": "Hebrews",
        
        // James
        "james": "James",
        
        // Peter
        "peter": "1 Peter",
        "1 peter": "1 Peter",
        "2 peter": "2 Peter",
        "first peter": "1 Peter",
        "second peter": "2 Peter",
        
        // Jude
        "jude": "Jude",
        "jewed": "Jude",
        
        // Revelation
        "revelation": "Revelation",
        "revelations": "Revelation",
        "rev-uh-lay-shun": "Revelation",
        "apocalypse": "Revelation"
    ]
    
    // MARK: - Number Word Mappings
    
    static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
        "twenty-one": 21, "twenty-two": 22, "twenty-three": 23, "twenty-four": 24, "twenty-five": 25,
        "twenty one": 21, "twenty two": 22, "twenty three": 23, "twenty four": 24, "twenty five": 25,
        "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90, "hundred": 100
    ]
    
    // MARK: - Ordinal Mappings
    
    static let ordinalWords: [String: Int] = [
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
        "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
        "eleventh": 11, "twelfth": 12, "thirteenth": 13, "fourteenth": 14, "fifteenth": 15
    ]
    
    // MARK: - Scripture Trigger Words
    
    static let triggerWords: Set<String> = [
        "chapter", "verse", "verses", "book of", "reading from",
        "turn to", "open to", "let's read", "according to",
        "the gospel of", "the book of", "the epistle to"
    ]
    
    // MARK: - Famous Verses (Implicit References)
    
    /// Well-known verse phrases that can be detected without explicit references
    static let famousVerses: [String: String] = [
        "for god so loved the world": "John 3:16",
        "in the beginning": "Genesis 1:1",
        "the lord is my shepherd": "Psalms 23:1",
        "i can do all things through christ": "Philippians 4:13",
        "trust in the lord with all your heart": "Proverbs 3:5",
        "be still and know that i am god": "Psalms 46:10",
        "love is patient love is kind": "1 Corinthians 13:4",
        "faith hope and love": "1 Corinthians 13:13",
        "do not fear for i am with you": "Isaiah 41:10",
        "the joy of the lord is your strength": "Nehemiah 8:10",
        "blessed are the peacemakers": "Matthew 5:9",
        "blessed are the poor in spirit": "Matthew 5:3",
        "ask and it shall be given": "Matthew 7:7",
        "i am the way the truth and the life": "John 14:6",
        "greater love has no one than this": "John 15:13",
        "all things work together for good": "Romans 8:28"
    ]
    
    // MARK: - Common Abbreviations
    
    static let abbreviations: [String: String] = [
        "gen": "Genesis",
        "ex": "Exodus",
        "exod": "Exodus",
        "lev": "Leviticus",
        "num": "Numbers",
        "deut": "Deuteronomy",
        "josh": "Joshua",
        "judg": "Judges",
        "ps": "Psalms",
        "psa": "Psalms",
        "prov": "Proverbs",
        "eccl": "Ecclesiastes",
        "isa": "Isaiah",
        "jer": "Jeremiah",
        "lam": "Lamentations",
        "ezek": "Ezekiel",
        "dan": "Daniel",
        "hos": "Hosea",
        "obad": "Obadiah",
        "mic": "Micah",
        "nah": "Nahum",
        "hab": "Habakkuk",
        "zeph": "Zephaniah",
        "hag": "Haggai",
        "zech": "Zechariah",
        "mal": "Malachi",
        "matt": "Matthew",
        "mk": "Mark",
        "lk": "Luke",
        "jn": "John",
        "rom": "Romans",
        "cor": "1 Corinthians",
        "gal": "Galatians",
        "eph": "Ephesians",
        "phil": "Philippians",
        "col": "Colossians",
        "thess": "1 Thessalonians",
        "tim": "1 Timothy",
        "tit": "Titus",
        "phm": "Philemon",
        "heb": "Hebrews",
        "jas": "James",
        "pet": "1 Peter",
        "rev": "Revelation"
    ]
}
