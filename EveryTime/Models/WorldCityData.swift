import Foundation

extension WorldCity {
    /// Country, capital, then the zone ids in use; the first zone belongs to the capital.
    static let countries: [(name: String, capital: String, zones: [String])] = [
        ("Ukraine", "Kyiv", ["Europe/Kyiv", "Europe/Kiev"]), ("Poland", "Warsaw", ["Europe/Warsaw"]),
        ("Germany", "Berlin", ["Europe/Berlin"]), ("France", "Paris", ["Europe/Paris"]),
        ("Spain", "Madrid", ["Europe/Madrid", "Atlantic/Canary"]), ("Portugal", "Lisbon", ["Europe/Lisbon", "Atlantic/Azores"]),
        ("Italy", "Rome", ["Europe/Rome"]), ("United Kingdom", "London", ["Europe/London"]),
        ("Ireland", "Dublin", ["Europe/Dublin"]), ("Netherlands", "Amsterdam", ["Europe/Amsterdam"]),
        ("Belgium", "Brussels", ["Europe/Brussels"]), ("Luxembourg", "Luxembourg", ["Europe/Luxembourg"]),
        ("Switzerland", "Bern", ["Europe/Zurich"]), ("Austria", "Vienna", ["Europe/Vienna"]),
        ("Czechia", "Prague", ["Europe/Prague"]), ("Slovakia", "Bratislava", ["Europe/Bratislava"]),
        ("Hungary", "Budapest", ["Europe/Budapest"]), ("Romania", "Bucharest", ["Europe/Bucharest"]),
        ("Bulgaria", "Sofia", ["Europe/Sofia"]), ("Greece", "Athens", ["Europe/Athens"]),
        ("Serbia", "Belgrade", ["Europe/Belgrade"]), ("Croatia", "Zagreb", ["Europe/Zagreb"]),
        ("Slovenia", "Ljubljana", ["Europe/Ljubljana"]), ("Bosnia and Herzegovina", "Sarajevo", ["Europe/Sarajevo"]),
        ("North Macedonia", "Skopje", ["Europe/Skopje"]), ("Albania", "Tirana", ["Europe/Tirane"]),
        ("Montenegro", "Podgorica", ["Europe/Podgorica"]), ("Kosovo", "Pristina", ["Europe/Belgrade"]),
        ("Moldova", "Chișinău", ["Europe/Chisinau"]), ("Belarus", "Minsk", ["Europe/Minsk"]),
        ("Lithuania", "Vilnius", ["Europe/Vilnius"]), ("Latvia", "Riga", ["Europe/Riga"]),
        ("Estonia", "Tallinn", ["Europe/Tallinn"]), ("Finland", "Helsinki", ["Europe/Helsinki"]),
        ("Sweden", "Stockholm", ["Europe/Stockholm"]), ("Norway", "Oslo", ["Europe/Oslo"]),
        ("Denmark", "Copenhagen", ["Europe/Copenhagen"]), ("Iceland", "Reykjavik", ["Atlantic/Reykjavik"]),
        ("Malta", "Valletta", ["Europe/Malta"]), ("Cyprus", "Nicosia", ["Asia/Nicosia"]),
        ("Turkey", "Ankara", ["Europe/Istanbul"]), ("Russia", "Moscow", ["Europe/Moscow", "Asia/Yekaterinburg", "Asia/Novosibirsk", "Asia/Krasnoyarsk", "Asia/Irkutsk", "Asia/Yakutsk", "Asia/Vladivostok", "Asia/Magadan", "Asia/Kamchatka", "Europe/Kaliningrad", "Europe/Samara"]),
        ("Georgia", "Tbilisi", ["Asia/Tbilisi"]), ("Armenia", "Yerevan", ["Asia/Yerevan"]), ("Azerbaijan", "Baku", ["Asia/Baku"]),
        ("Kazakhstan", "Astana", ["Asia/Almaty", "Asia/Aqtau"]), ("Uzbekistan", "Tashkent", ["Asia/Tashkent"]),
        ("Kyrgyzstan", "Bishkek", ["Asia/Bishkek"]), ("Tajikistan", "Dushanbe", ["Asia/Dushanbe"]),
        ("Turkmenistan", "Ashgabat", ["Asia/Ashgabat"]), ("Afghanistan", "Kabul", ["Asia/Kabul"]),
        ("Pakistan", "Islamabad", ["Asia/Karachi"]), ("India", "New Delhi", ["Asia/Kolkata"]),
        ("Nepal", "Kathmandu", ["Asia/Kathmandu"]), ("Bhutan", "Thimphu", ["Asia/Thimphu"]),
        ("Bangladesh", "Dhaka", ["Asia/Dhaka"]), ("Sri Lanka", "Colombo", ["Asia/Colombo"]),
        ("Maldives", "Malé", ["Indian/Maldives"]), ("Myanmar", "Naypyidaw", ["Asia/Yangon"]),
        ("Thailand", "Bangkok", ["Asia/Bangkok"]), ("Laos", "Vientiane", ["Asia/Vientiane"]),
        ("Cambodia", "Phnom Penh", ["Asia/Phnom_Penh"]), ("Vietnam", "Hanoi", ["Asia/Ho_Chi_Minh"]),
        ("Malaysia", "Kuala Lumpur", ["Asia/Kuala_Lumpur"]), ("Singapore", "Singapore", ["Asia/Singapore"]),
        ("Indonesia", "Jakarta", ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"]),
        ("Brunei", "Bandar Seri Begawan", ["Asia/Brunei"]), ("Philippines", "Manila", ["Asia/Manila"]),
        ("Timor-Leste", "Dili", ["Asia/Dili"]), ("China", "Beijing", ["Asia/Shanghai", "Asia/Urumqi"]),
        ("Hong Kong", "Hong Kong", ["Asia/Hong_Kong"]), ("Macau", "Macau", ["Asia/Macau"]),
        ("Taiwan", "Taipei", ["Asia/Taipei"]), ("Mongolia", "Ulaanbaatar", ["Asia/Ulaanbaatar"]),
        ("South Korea", "Seoul", ["Asia/Seoul"]), ("North Korea", "Pyongyang", ["Asia/Pyongyang"]),
        ("Japan", "Tokyo", ["Asia/Tokyo"]), ("Iran", "Tehran", ["Asia/Tehran"]), ("Iraq", "Baghdad", ["Asia/Baghdad"]),
        ("Syria", "Damascus", ["Asia/Damascus"]), ("Lebanon", "Beirut", ["Asia/Beirut"]),
        ("Israel", "Jerusalem", ["Asia/Jerusalem"]), ("Palestine", "Ramallah", ["Asia/Hebron"]),
        ("Jordan", "Amman", ["Asia/Amman"]), ("Saudi Arabia", "Riyadh", ["Asia/Riyadh"]),
        ("Kuwait", "Kuwait City", ["Asia/Kuwait"]), ("Bahrain", "Manama", ["Asia/Bahrain"]),
        ("Qatar", "Doha", ["Asia/Qatar"]), ("United Arab Emirates", "Abu Dhabi", ["Asia/Dubai"]),
        ("Oman", "Muscat", ["Asia/Muscat"]), ("Yemen", "Sanaa", ["Asia/Aden"]),
        ("Egypt", "Cairo", ["Africa/Cairo"]), ("Libya", "Tripoli", ["Africa/Tripoli"]),
        ("Tunisia", "Tunis", ["Africa/Tunis"]), ("Algeria", "Algiers", ["Africa/Algiers"]),
        ("Morocco", "Rabat", ["Africa/Casablanca"]), ("Sudan", "Khartoum", ["Africa/Khartoum"]),
        ("South Sudan", "Juba", ["Africa/Juba"]), ("Ethiopia", "Addis Ababa", ["Africa/Addis_Ababa"]),
        ("Eritrea", "Asmara", ["Africa/Asmara"]), ("Somalia", "Mogadishu", ["Africa/Mogadishu"]),
        ("Djibouti", "Djibouti", ["Africa/Djibouti"]), ("Kenya", "Nairobi", ["Africa/Nairobi"]),
        ("Uganda", "Kampala", ["Africa/Kampala"]), ("Tanzania", "Dodoma", ["Africa/Dar_es_Salaam"]),
        ("Rwanda", "Kigali", ["Africa/Kigali"]), ("Burundi", "Gitega", ["Africa/Bujumbura"]),
        ("DR Congo", "Kinshasa", ["Africa/Kinshasa", "Africa/Lubumbashi"]), ("Congo", "Brazzaville", ["Africa/Brazzaville"]),
        ("Angola", "Luanda", ["Africa/Luanda"]), ("Zambia", "Lusaka", ["Africa/Lusaka"]),
        ("Zimbabwe", "Harare", ["Africa/Harare"]), ("Mozambique", "Maputo", ["Africa/Maputo"]),
        ("Malawi", "Lilongwe", ["Africa/Blantyre"]), ("Madagascar", "Antananarivo", ["Indian/Antananarivo"]),
        ("Mauritius", "Port Louis", ["Indian/Mauritius"]), ("Botswana", "Gaborone", ["Africa/Gaborone"]),
        ("Namibia", "Windhoek", ["Africa/Windhoek"]), ("South Africa", "Pretoria", ["Africa/Johannesburg"]),
        ("Lesotho", "Maseru", ["Africa/Maseru"]), ("Eswatini", "Mbabane", ["Africa/Mbabane"]),
        ("Nigeria", "Abuja", ["Africa/Lagos"]), ("Ghana", "Accra", ["Africa/Accra"]),
        ("Ivory Coast", "Yamoussoukro", ["Africa/Abidjan"]), ("Senegal", "Dakar", ["Africa/Dakar"]),
        ("Mali", "Bamako", ["Africa/Bamako"]), ("Niger", "Niamey", ["Africa/Niamey"]),
        ("Chad", "N'Djamena", ["Africa/Ndjamena"]), ("Cameroon", "Yaoundé", ["Africa/Douala"]),
        ("Gabon", "Libreville", ["Africa/Libreville"]), ("Benin", "Porto-Novo", ["Africa/Porto-Novo"]),
        ("Togo", "Lomé", ["Africa/Lome"]), ("Burkina Faso", "Ouagadougou", ["Africa/Ouagadougou"]),
        ("Guinea", "Conakry", ["Africa/Conakry"]), ("Sierra Leone", "Freetown", ["Africa/Freetown"]),
        ("Liberia", "Monrovia", ["Africa/Monrovia"]), ("Gambia", "Banjul", ["Africa/Banjul"]),
        ("Mauritania", "Nouakchott", ["Africa/Nouakchott"]), ("Cape Verde", "Praia", ["Atlantic/Cape_Verde"]),
        ("United States", "Washington DC", ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu", "America/Phoenix"]),
        ("Canada", "Ottawa", ["America/Toronto", "America/Vancouver", "America/Edmonton", "America/Winnipeg", "America/Halifax", "America/St_Johns"]),
        ("Mexico", "Mexico City", ["America/Mexico_City", "America/Tijuana", "America/Cancun"]),
        ("Guatemala", "Guatemala City", ["America/Guatemala"]), ("Belize", "Belmopan", ["America/Belize"]),
        ("El Salvador", "San Salvador", ["America/El_Salvador"]), ("Honduras", "Tegucigalpa", ["America/Tegucigalpa"]),
        ("Nicaragua", "Managua", ["America/Managua"]), ("Costa Rica", "San José", ["America/Costa_Rica"]),
        ("Panama", "Panama City", ["America/Panama"]), ("Cuba", "Havana", ["America/Havana"]),
        ("Jamaica", "Kingston", ["America/Jamaica"]), ("Haiti", "Port-au-Prince", ["America/Port-au-Prince"]),
        ("Dominican Republic", "Santo Domingo", ["America/Santo_Domingo"]), ("Puerto Rico", "San Juan", ["America/Puerto_Rico"]),
        ("Bahamas", "Nassau", ["America/Nassau"]), ("Trinidad and Tobago", "Port of Spain", ["America/Port_of_Spain"]),
        ("Colombia", "Bogotá", ["America/Bogota"]), ("Venezuela", "Caracas", ["America/Caracas"]),
        ("Ecuador", "Quito", ["America/Guayaquil"]), ("Peru", "Lima", ["America/Lima"]),
        ("Bolivia", "La Paz", ["America/La_Paz"]), ("Chile", "Santiago", ["America/Santiago"]),
        ("Argentina", "Buenos Aires", ["America/Argentina/Buenos_Aires"]), ("Uruguay", "Montevideo", ["America/Montevideo"]),
        ("Paraguay", "Asunción", ["America/Asuncion"]), ("Brazil", "Brasília", ["America/Sao_Paulo", "America/Manaus", "America/Fortaleza", "America/Recife"]),
        ("Guyana", "Georgetown", ["America/Guyana"]), ("Suriname", "Paramaribo", ["America/Paramaribo"]),
        ("Australia", "Canberra", ["Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane", "Australia/Perth", "Australia/Adelaide", "Australia/Darwin", "Australia/Hobart"]),
        ("New Zealand", "Wellington", ["Pacific/Auckland"]), ("Fiji", "Suva", ["Pacific/Fiji"]),
        ("Papua New Guinea", "Port Moresby", ["Pacific/Port_Moresby"]), ("Samoa", "Apia", ["Pacific/Apia"]),
        ("Tonga", "Nukuʻalofa", ["Pacific/Tongatapu"]), ("Guam", "Hagåtña", ["Pacific/Guam"]),
    ]

    /// Spellings people type that the zone database lacks or spells differently.
    static let renames = ["Kiev": "Kyiv", "Ho Chi Minh": "Ho Chi Minh City"]

    /// Zone ids and the capital's name for every country whose name contains the query.
    static func keys(inCountryMatching query: String) -> Set<String> {
        Set(countries.filter { $0.name.localizedCaseInsensitiveContains(query) }.flatMap { $0.zones + [$0.capital] })
    }

    private static let countryByKey: [String: String] = {
        var map: [String: String] = [:]
        for c in countries.reversed() {
            for zone in c.zones { map[zone] = c.name }
            map[c.capital] = c.name
        }
        return map
    }()

    var country: String? { Self.countryByKey[name] ?? Self.countryByKey[timeZoneIdentifier] }
}
