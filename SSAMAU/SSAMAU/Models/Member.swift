import Foundation

/// Full member profile. Mirrors the `members` table + `committee_name`
/// joined by `members.getOwn`. Most fields optional — schema has
/// extended via migrations past the initial set, and not every member
/// has every field populated.
struct Member: Codable, Identifiable, Equatable {
    let id: String                              // member_id, MBR_XXXX
    let fullName: String?                       // defensive — guard the spec, not the schema
    let preferredName: String?
    let nameEn: String?
    let email: String?
    let phone: String?
    let whatsapp: String?
    let gender: String?
    let nationalId: String?
    let dateOfBirth: String?                    // YYYY-MM-DD
    let profilePhotoUrl: String?
    let cvUrl: String?
    let addressMelbourne: String?
    let linkedinUrl: String?
    let skillsHobbies: String?
    let aboutSelf: String?
    let scholarshipEntity: String?
    let scholarshipEntityOther: String?
    let studyLevel: String?
    let degreeField: String?
    let university: String?
    let universityOther: String?
    let studyStartedWindow: String?
    let expectedGraduationWindow: String?
    let committeeId: String?
    let committeeName: String?                  // joined
    let clubRole: String?                       // "Member", "Committee Head", etc.
    let status: String?                         // "Active" | "Inactive"
    let joinDate: String?                       // YYYY-MM-DD
    let totalHours: Double                      // see init — postgres NUMERIC arrives as String

    var displayName: String { preferredName ?? fullName ?? id }
    var isActive: Bool { (status ?? "Active") == "Active" }

    enum CodingKeys: String, CodingKey {
        case email, phone, whatsapp, gender, status, university
        case id = "member_id"
        case fullName = "full_name"
        case preferredName = "preferred_name"
        case nameEn = "name_en"
        case nationalId = "national_id"
        case dateOfBirth = "date_of_birth"
        case profilePhotoUrl = "profile_photo_url"
        case cvUrl = "cv_url"
        case addressMelbourne = "address_melbourne"
        case linkedinUrl = "linkedin_url"
        case skillsHobbies = "skills_hobbies"
        case aboutSelf = "about_self"
        case scholarshipEntity = "scholarship_entity"
        case scholarshipEntityOther = "scholarship_entity_other"
        case studyLevel = "study_level"
        case degreeField = "degree_field"
        case universityOther = "university_other"
        case studyStartedWindow = "study_started_window"
        case expectedGraduationWindow = "expected_graduation_window"
        case committeeId = "committee_id"
        case committeeName = "committee_name"
        case clubRole = "club_role"
        case joinDate = "join_date"
        case totalHours = "total_hours"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName               = try c.decodeIfPresent(String.self, forKey: .fullName)
        preferredName          = try c.decodeIfPresent(String.self, forKey: .preferredName)
        nameEn                 = try c.decodeIfPresent(String.self, forKey: .nameEn)
        email                  = try c.decodeIfPresent(String.self, forKey: .email)
        phone                  = try c.decodeIfPresent(String.self, forKey: .phone)
        whatsapp               = try c.decodeIfPresent(String.self, forKey: .whatsapp)
        gender                 = try c.decodeIfPresent(String.self, forKey: .gender)
        nationalId             = try c.decodeIfPresent(String.self, forKey: .nationalId)
        dateOfBirth            = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
        profilePhotoUrl        = try c.decodeIfPresent(String.self, forKey: .profilePhotoUrl)
        cvUrl                  = try c.decodeIfPresent(String.self, forKey: .cvUrl)
        addressMelbourne       = try c.decodeIfPresent(String.self, forKey: .addressMelbourne)
        linkedinUrl            = try c.decodeIfPresent(String.self, forKey: .linkedinUrl)
        skillsHobbies          = try c.decodeIfPresent(String.self, forKey: .skillsHobbies)
        aboutSelf              = try c.decodeIfPresent(String.self, forKey: .aboutSelf)
        scholarshipEntity      = try c.decodeIfPresent(String.self, forKey: .scholarshipEntity)
        scholarshipEntityOther = try c.decodeIfPresent(String.self, forKey: .scholarshipEntityOther)
        studyLevel             = try c.decodeIfPresent(String.self, forKey: .studyLevel)
        degreeField            = try c.decodeIfPresent(String.self, forKey: .degreeField)
        university             = try c.decodeIfPresent(String.self, forKey: .university)
        universityOther        = try c.decodeIfPresent(String.self, forKey: .universityOther)
        studyStartedWindow     = try c.decodeIfPresent(String.self, forKey: .studyStartedWindow)
        expectedGraduationWindow = try c.decodeIfPresent(String.self, forKey: .expectedGraduationWindow)
        committeeId            = try c.decodeIfPresent(String.self, forKey: .committeeId)
        committeeName          = try c.decodeIfPresent(String.self, forKey: .committeeName)
        clubRole               = try c.decodeIfPresent(String.self, forKey: .clubRole)
        status                 = try c.decodeIfPresent(String.self, forKey: .status)
        joinDate               = try c.decodeIfPresent(String.self, forKey: .joinDate)

        // Postgres NUMERIC(10,2) → postgres.js serializes as String to preserve
        // precision. Accept Double too in case the encoder ever changes.
        if let d = try? c.decode(Double.self, forKey: .totalHours) {
            totalHours = d
        } else if let s = try? c.decode(String.self, forKey: .totalHours),
                  let d = Double(s) {
            totalHours = d
        } else {
            totalHours = 0
        }
    }
}
