import Foundation

/// Full member profile. Mirrors the `members` table + `committee_name`
/// joined by `members.getOwn`. Most fields optional — schema has
/// extended via migrations past the initial set, and not every member
/// has every field populated.
struct Member: Codable, Identifiable, Equatable {
    let id: String                              // member_id, MBR_XXXX
    let fullName: String
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
    let status: String                          // "Active" | "Inactive"
    let joinDate: String?                       // YYYY-MM-DD
    let totalHours: Double

    var displayName: String { preferredName ?? fullName }
    var isActive: Bool { status == "Active" }

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
}
