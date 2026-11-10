/// How active she is in a typical week. The multiplier turns BMR into TDEE.
/// Raw values are stable keys for her data file; the Polish labels live in the UI.
public enum ActivityLevel: String, Codable, Sendable, CaseIterable {
    case sedentary  // siedzący, bez treningów
    case light      // lekki – 1–3 treningi w tygodniu
    case moderate   // umiarkowany – 3–5 treningów
    case high       // wysoki – 6–7 treningów

    public var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .high: 1.725
        }
    }
}

/// What her daily targets are computed from. She enters it herself; there are no defaults in code.
public struct NutritionProfile: Codable, Sendable, Hashable {
    public var birthYear: Int
    public var heightCm: Double
    /// The weight she gave. Used until she has weigh-ins; after that the app passes her trend weight.
    public var weightKg: Double
    public var activity: ActivityLevel
    /// How many kcal a day below her TDEE she would like to eat; 0 = maintenance.
    public var deficitKcal: Double

    public init(birthYear: Int, heightCm: Double, weightKg: Double, activity: ActivityLevel, deficitKcal: Double) {
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activity = activity
        self.deficitKcal = deficitKcal
    }
}

/// Whether the daily targets follow her profile or are numbers she typed herself.
///
/// Stored as `{"mode": "automatic"}` or `{"mode": "manual", "macros": {...}}`. Whatever this
/// version can't use (no mode, a mode from a newer version, manual without numbers) reads as
/// automatic, and extra keys are ignored. A damaged `macros` object in a manual setting is an
/// error, so her own numbers are never dropped silently.
public enum TargetsSetting: Codable, Sendable, Hashable {
    /// Computed from her profile and weight trend each time, so they never go stale.
    case automatic
    /// Her own numbers.
    case manual(Macros)

    private enum Keys: String, CodingKey {
        case mode, macros
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "automatic"
        if mode == "manual", let macros = try container.decodeIfPresent(Macros.self, forKey: .macros) {
            self = .manual(macros)
        } else {
            self = .automatic
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .automatic:
            try container.encode("automatic", forKey: .mode)
        case .manual(let macros):
            try container.encode("manual", forKey: .mode)
            try container.encode(macros, forKey: .macros)
        }
    }
}

/// Why the targets differ from the plain formula, so the app can explain it gently.
public enum TargetAdjustment: String, Codable, Sendable, Hashable, CaseIterable {
    /// The deficit she asked for was more than 20 % of her TDEE.
    case deficitLimited
    /// Energy was raised to the minimum (1200 kcal or her BMR, at most her TDEE); the deficit is smaller.
    case raisedToMinimum
    /// Protein went below 1.8 g per kg of the reference weight (never below 1.6) to leave room
    /// for carbohydrates.
    case proteinLowered
    /// Fat went below 0.8 g per kg of the reference weight (never below 25 % of the energy) to
    /// leave room for carbohydrates.
    case fatLowered
}

public struct TargetResult: Sendable, Hashable {
    /// Daily kcal and grams of protein, carbohydrates and fat – whole numbers.
    public var targets: Macros
    /// Basal metabolic rate, kcal a day.
    public var bmr: Double
    /// BMR × activity: what she burns on a typical day.
    public var tdee: Double
    /// TDEE minus the (unrounded) kcal target, after the guardrails; never negative.
    public var appliedDeficit: Double
    /// In the order they were applied (the order of `TargetAdjustment.allCases`).
    public var adjustments: [TargetAdjustment]

    public init(targets: Macros, bmr: Double, tdee: Double, appliedDeficit: Double, adjustments: [TargetAdjustment]) {
        self.targets = targets
        self.bmr = bmr
        self.tdee = tdee
        self.appliedDeficit = appliedDeficit
        self.adjustments = adjustments
    }
}

/// Daily targets from her profile. An estimate, and the app says so ("to szacunek").
///
/// - BMR by Mifflin–St Jeor for women: 10·kg + 6.25·cm − 5·age − 161, age clamped to 15…100.
///   TDEE = BMR × activity multiplier.
/// - Deficit: what she asked for, kept within 0…20 % of TDEE (`deficitLimited` when capped).
/// - kcal = TDEE − deficit, but at least max(1200, BMR); when even her TDEE is lower than that,
///   kcal = TDEE, so no deficit at all (`raisedToMinimum`; the deficit shrinks to match).
/// - The per-kilogram parts use a reference weight: her weight, but at most the weight at BMI 25
///   for her height (25 · h², h in metres). Protein needs follow lean mass rather than total
///   weight, so a heavier profile isn't asked for 180 g of protein and a low-carbohydrate day.
///   Energy (the BMR) still uses her real weight.
/// - Protein 1.8 g/kg; fat max(0.8 g/kg, 25 % of kcal); carbohydrates get the rest.
/// - Under 130 g of carbohydrates (the usual daily minimum): protein goes down towards 1.6 g/kg
///   (`proteinLowered`), then fat towards 25 % of kcal (`fatLowered`), each only as far as needed.
///   If that is still not enough, the result is accepted; carbohydrates never go below 0.
/// - Each target is rounded to a whole number at the end.
public enum TargetCalculator {
    /// The largest deficit, as a share of TDEE.
    public static let maxDeficitShare = 0.2
    /// kcal are never set below this or her BMR (unless her TDEE is lower still).
    public static let minimumKcal: Double = 1200
    /// Per kg of the reference weight, like the two below.
    public static let proteinPerKg = 1.8
    public static let minimumProteinPerKg = 1.6
    public static let fatPerKg = 0.8
    /// The least fat, as a share of the kcal target.
    public static let minimumFatShare = 0.25
    /// Grams of carbohydrates that protein and fat make room for, if they can.
    public static let minimumCarbs: Double = 130
    /// The reference weight is at most the weight at this BMI.
    public static let referenceBMI: Double = 25

    /// `weightKg` overrides the profile weight: the app passes her trend weight once she has weigh-ins.
    /// `year` is the current year (her age is the year minus her birth year).
    public static func compute(profile: NutritionProfile, weightKg: Double? = nil, year: Int) -> TargetResult {
        let kg = weightKg ?? profile.weightKg
        // In Double, so even a nonsense birth year from a damaged file can't overflow.
        let yearsSinceBirth = Double(year) - Double(profile.birthYear)
        let age = Swift.min(Swift.max(yearsSinceBirth, 15), 100)

        let weightPart = 10 * kg
        let heightPart = 6.25 * profile.heightCm
        let agePart = 5 * age
        let bmr = weightPart + heightPart - agePart - 161
        let tdee = bmr * profile.activity.multiplier

        var adjustments: [TargetAdjustment] = []

        // A gentle deficit: at most a fifth of what she burns. A negative one counts as 0.
        let wanted = Swift.max(0, profile.deficitKcal)
        let cap = Swift.max(0, maxDeficitShare * tdee)
        var deficit = wanted
        if wanted > cap {
            deficit = cap
            adjustments.append(.deficitLimited)
        }

        // Never below 1200 kcal or her BMR, but never above her TDEE either.
        var kcal = tdee - deficit
        let energyFloor = Swift.min(Swift.max(minimumKcal, bmr), tdee)
        if kcal < energyFloor {
            kcal = energyFloor
            deficit = tdee - kcal
            adjustments.append(.raisedToMinimum)
        }

        // Her weight, but at most the weight at BMI 25 for her height. Written as h · h,
        // because this file doesn't import Foundation (no `pow`).
        let heightM = profile.heightCm / 100
        let referenceKg = Swift.min(kg, referenceBMI * heightM * heightM)

        var protein = proteinPerKg * referenceKg
        let fatFloor = minimumFatShare * kcal / 9
        var fat = Swift.max(fatPerKg * referenceKg, fatFloor)

        // Too few carbohydrates left: give up some protein first, then some fat.
        // `missing` is in grams of carbohydrates; a gram of protein makes room for one gram,
        // a gram of fat for 9/4 g.
        var missing = minimumCarbs - carbsLeft(kcal: kcal, protein: protein, fat: fat)
        if missing > 0 {
            let proteinCut = Swift.min(missing, Swift.max(0, protein - minimumProteinPerKg * referenceKg))
            if proteinCut > 0 {
                protein -= proteinCut
                missing -= proteinCut
                adjustments.append(.proteinLowered)
            }
            if missing > 0 {
                let fatCut = Swift.min(missing * 4 / 9, Swift.max(0, fat - fatFloor))
                if fatCut > 0 {
                    fat -= fatCut
                    adjustments.append(.fatLowered)
                }
            }
        }
        let carbs = Swift.max(0, carbsLeft(kcal: kcal, protein: protein, fat: fat))

        let targets = Macros(kcal: kcal.rounded(), protein: protein.rounded(),
                             carbs: carbs.rounded(), fat: fat.rounded())
        return TargetResult(targets: targets, bmr: bmr, tdee: tdee,
                            appliedDeficit: deficit, adjustments: adjustments)
    }

    /// Grams of carbohydrates that fit into `kcal` next to the given protein and fat.
    private static func carbsLeft(kcal: Double, protein: Double, fat: Double) -> Double {
        let proteinKcal = 4 * protein
        let fatKcal = 9 * fat
        return (kcal - proteinKcal - fatKcal) / 4
    }
}
